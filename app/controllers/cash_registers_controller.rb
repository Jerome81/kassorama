class CashRegistersController < ApplicationController
  before_action :set_cash_register, only: %i[ edit update destroy ]

  def index
    @cash_registers = CashRegister.all
    
    # Prepare sales stats
    @sales_today = {}
    @sales_yesterday = {}
    
    today = Date.current
    yesterday = Date.yesterday
    
    # Fetch orders for today and yesterday
    orders = Order.where(status: 'completed', created_at: yesterday.beginning_of_day..today.end_of_day)
                  .select(:cash_register_id, :created_at, :total_amount)
    
    grouped = orders.group_by { |o| [o.cash_register_id, o.created_at.to_date] }
    
    @cash_registers.each do |cr|
        @sales_today[cr.id] = (grouped[[cr.id, today]] || []).sum(&:total_amount)
        @sales_yesterday[cr.id] = (grouped[[cr.id, yesterday]] || []).sum(&:total_amount)
    end
  end



  def new
    @cash_register = CashRegister.new
    @cash_register.sections.build
  end

  def edit
    @cash_register.sections.build
  end

  def create
    @cash_register = CashRegister.new(cash_register_params)

    if @cash_register.save
      redirect_to cash_registers_url, notice: "Cash register was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @cash_register.update(cash_register_params)
      redirect_to cash_registers_url, notice: "Cash register was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @cash_register.destroy!

    redirect_to cash_registers_url, notice: "Cash register was successfully destroyed."
  end

  def transactions
    @cash_register = CashRegister.find(params[:id])
    
    orders = @cash_register.orders.where(status: 'completed')
    manual_transactions = Transaction.where(cash_register_id: @cash_register.id) 

    # Combining list:
    timeline_items = []
    
    orders.each do |o|
      timeline_items << { type: 'order', object: o, timestamp: o.updated_at }
    end
    
    manual_transactions.each do |t|
      timeline_items << { type: 'transaction', object: t, timestamp: t.created_at }
    end
    
    # Sort DESC
    timeline_items.sort_by! { |item| item[:timestamp] }.reverse!
    
    current_balance = @cash_register.amount || 0
    
    @history = []
    
    timeline_items.each do |item|
       obj = item[:object]
       row = {
         type: item[:type],
         data: obj,
         balance: current_balance,
         timestamp: item[:timestamp]
       }
       @history << row
       
       # Reverse calculation of balance BEFORE this event
       if item[:type] == 'order'
         if obj.payment_method == 'cash'
           current_balance -= (obj.total_amount || 0)
         end
       elsif item[:type] == 'transaction'
         if obj.transaction_type == 'removal'
            # Removal reduced balance, so we add it back
            current_balance += (obj.amount || 0)
         elsif obj.transaction_type == 'reconciliation'
            # Reconciliation adjusted balance by diff. new = old + diff. old = new - diff.
            current_balance -= (obj.amount || 0)
         end
       end
    end
    
    @history_by_day = @history.group_by { |h| h[:timestamp].to_date }
  end

  def cash_count
    @cash_register = CashRegister.find(params[:id])
  end

  def save_cash_count
    @cash_register = CashRegister.find(params[:id])
    counted_amount = params[:total_counted].to_f
    expected_amount = @cash_register.amount || 0
    difference = counted_amount - expected_amount

    ActiveRecord::Base.transaction do
      @cash_register.update!(amount: counted_amount)
      
      Transaction.create!(
        transaction_type: 'reconciliation',
        amount: difference, # This will be negative if money is missing, positive if extra
        description: "Kassensturz"
      )
    end

    redirect_to pos_path(@cash_register), notice: "Kassensturz erfolgreich verbucht. Neuer Stand: #{helpers.number_to_currency(counted_amount)}"
  end

  private
    def set_cash_register
      @cash_register = CashRegister.find(params[:id])
    end

    def cash_register_params
      params.require(:cash_register).permit(:name, :status, :stock_location_id, :amount, :precreated_tabs, sections_attributes: [:id, :name, :_destroy])
    end
end
