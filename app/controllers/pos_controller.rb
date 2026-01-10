class PosController < ApplicationController
  before_action :set_register, only: [:show, :add_item, :checkout, :update_item_quantity, :remove_item, :payment, :process_payment, :add_free_price_item, :save_free_price_item, :withdraw_cash, :process_withdrawal, :park_order, :restore_order, :update_item_discount]
  before_action :set_current_order, only: [:show, :add_item, :checkout, :update_item_quantity, :remove_item, :payment, :process_payment, :save_free_price_item, :park_order, :restore_order, :update_item_discount]

  def index
    @cash_registers = CashRegister.all
  end

  def show
    @order_items = @order.order_items.includes(:article)
    @total = @order_items.sum { |item| item.net_price || (item.quantity * item.unit_price) }
    @parked_orders = @cash_register.orders.parked.order(updated_at: :desc)
    
    @sections = @cash_register.sections
    if params[:section_id].present?
      @active_section = @sections.find_by(id: params[:section_id])
    end
    
    if @active_section.nil? && @sections.any?
      @active_section = @sections.first
    end

    if params[:search_query].present?
      articles = Article.where(status: 'active').where(barcode: params[:search_query])
      articles = Article.where(status: 'active').where(sku: params[:search_query]) if articles.empty?
      articles = Article.where(status: 'active').where("name LIKE ?", "%#{params[:search_query]}%") if articles.empty?
      articles = Article.where(status: 'active').where("\"group\" LIKE ?", "%#{params[:search_query]}%") if articles.empty?
      
      @articles = articles.order(:group, :name)
      flash.now[:notice] = "Found #{@articles.count} results for '#{params[:search_query]}'" if @articles.any?
    elsif @active_section
      # Fetch articles manually assigned to the section OR matching the group filter

      
      # We want active articles that are EITHER in the manual list OR match the group
      @articles = Article.where(status: 'active')
                         .left_joins(:article_sections)
                         .where("\"articles\".\"group\" = ? OR article_sections.section_id = ?", @active_section.group_filter, @active_section.id)
                         .distinct
                         .order(:group, :name)
    else
      @articles = Article.where(status: 'active').order(:group, :name)
    end
  end

  def add_item
    query = params[:query]
    
    # Prioritized Search:
    # 1. Barcode (exact)
    # 2. SKU (exact)
    # 3. Name (partial)
    # 4. Group (partial)
    
    articles = Article.where(status: 'active').where(barcode: query)
    articles = Article.where(status: 'active').where(sku: query) if articles.empty?
    articles = Article.where(status: 'active').where("name LIKE ?", "%#{query}%") if articles.empty?
    articles = Article.where(status: 'active').where("\"group\" LIKE ?", "%#{query}%") if articles.empty?
    
    if articles.count == 1
      article = articles.first
      
      if article.price_type == 'free'
        redirect_to add_free_price_item_pos_path(@cash_register, article_id: article.id, section_id: params[:section_id])
      else
        @item = @order.order_items.find_or_initialize_by(article: article)
        @item.quantity = (@item.quantity || 0) + 1
        @item.unit_price = article.price
        @item.gross_price = @item.quantity * @item.unit_price
        @item.discount = 0
        @item.net_price = @item.gross_price
        @item.save!
        flash[:notice] = "Added #{article.name}"
        redirect_to pos_path(@cash_register, section_id: params[:section_id])
      end
    elsif articles.count > 1
      # Redirect to show action with search results
      redirect_to pos_path(@cash_register, section_id: params[:section_id], search_query: query)
    else
      flash[:alert] = "Article not found"
      redirect_to pos_path(@cash_register, section_id: params[:section_id])
    end
  end

  def update_item_quantity
    @item = @order.order_items.find(params[:item_id])
    change = params[:change].to_i
    new_quantity = @item.quantity + change
    
    if new_quantity > 0
      @item.assign_attributes(quantity: new_quantity)
      @item.gross_price = @item.quantity * @item.unit_price
      @item.discount ||= 0
      @item.net_price = @item.gross_price - @item.discount
      @item.save!
    else
      @item.destroy
    end
    
    redirect_to pos_path(@cash_register, section_id: params[:section_id])
  end

  def remove_item
    @item = @order.order_items.find(params[:item_id])
    @item.destroy
    redirect_to pos_path(@cash_register, section_id: params[:section_id]), notice: "Removed #{@item.article.name}"
  end

  def payment
    @total = @order.order_items.sum { |item| item.net_price || (item.quantity * item.unit_price) }
  end

  def process_payment
    if @order.order_items.empty?
      redirect_to pos_path(@cash_register), alert: "Cart is empty"
      return
    end

    stock_location = @cash_register.stock_location
    
    unless stock_location
      redirect_to pos_path(@cash_register), alert: "This register is not linked to a stock location. Please contact admin."
      return
    end

    # Handle Discount
    discount_value = params[:discount_value].to_f
    discount_type = params[:discount_type] # 'percent' or 'fixed'
    
    # Check total gross first
    total_gross = @order.order_items.sum { |i| i.quantity * i.unit_price }
    effective_percent = 0.0

    if discount_value > 0 && total_gross > 0
        if discount_type == 'percent'
            effective_percent = discount_value
        elsif discount_type == 'fixed'
            # Calculate percent representation of the fixed amount
            effective_percent = (discount_value / total_gross) * 100.0
        end
    end
    
    @order.order_items.each do |item|
       gross = item.quantity * item.unit_price
       item.gross_price = gross 
       
       if effective_percent > 0
          d_amt = (gross * (effective_percent / 100.0)).round(2)
          item.discount = d_amt
          item.net_price = gross - d_amt
       end
       item.save!
    end

    # Correction for rounding to 0.05
    current_total = @order.order_items.sum(:net_price)
    rounded_total = (current_total * 20).round / 20.0
    rounding_diff = rounded_total - current_total
    
    if rounding_diff.abs > 0.001
       if first_item = @order.order_items.order(:created_at).first
          first_item.discount -= rounding_diff
          first_item.net_price += rounding_diff
          first_item.save!
       end
    end

    discount_amount = @order.order_items.sum(:discount)
    final_total = @order.order_items.sum(:net_price)
    
    payment_method = params[:payment_method]
    voucher_amount = params[:voucher_amount].to_f
    voucher_info = params[:voucher_code]
    if voucher_amount > 0
       voucher_info = [voucher_info, "Amount: #{helpers.number_to_currency(voucher_amount)}"].compact.join(" - ")
    end

    success = false
    ActiveRecord::Base.transaction do
      effective_voucher_amount = 0.0
      voucher_ratio = 0.0
      
      if final_total > 0
        effective_voucher_amount = [voucher_amount, final_total].min
        voucher_ratio = effective_voucher_amount / final_total
      end

      # Track accumulated voucher amount to fix rounding on the last item
      accumulated_voucher_amount = 0.0
      order_items_array = @order.order_items.includes(:article).to_a
      
      order_items_array.each_with_index do |item, index|
        unless item.article.price_type == 'free'
          stock = Stock.find_or_initialize_by(article: item.article, location: stock_location)
          # We allow negative stock (tracking over-sells/discrepancies)
          stock.quantity = (stock.quantity || 0) - item.quantity
          stock.save!
        end
        item.article.increment!(:sales_count, item.quantity)

        # Calculate Split
        if index == order_items_array.size - 1
           # Last item takes the difference/remainder to ensure total matches effective_voucher_amount
           amount_voucher = (effective_voucher_amount - accumulated_voucher_amount).round(2)
        else
           amount_voucher = (item.net_price * voucher_ratio).round(2)
        end
        
        accumulated_voucher_amount += amount_voucher
        amount_remaining = item.net_price - amount_voucher
        
        # Voucher Entry (2215)
        if amount_voucher != 0
          Entry.create!(
             booking_date: Date.current,
             debit_account: '2215',
             credit_account: item.article.booking_account,
             tax_code: item.article.tax_code&.rate&.to_s,
             amount: amount_voucher,
             reference_number: "#{@order.id}/#{item.article.name}",
             description: "POS Sale"
          )
        end
        
        # Remaining Payment Entry
        if amount_remaining != 0
          Entry.create!(
             booking_date: Date.current,
             debit_account: (payment_method == 'cash' ? '1000' : '1030'),
             credit_account: item.article.booking_account,
             tax_code: item.article.tax_code&.rate&.to_s,
             amount: amount_remaining,
             reference_number: "#{@order.id}/#{item.article.name}",
             description: "POS Sale"
          )
        end
      end

      @order.update!(
        status: :completed, 
        total_amount: final_total,
        discount: discount_amount,
        voucher: voucher_info,
        payment_method: payment_method,
        user_name: current_user.name
      )
      
      # Update Cash Register Amount if Cash Payment
      if payment_method == 'cash'
        # Only add the amount actually paid in cash (Total - Voucher)
        cash_paid = [final_total - voucher_amount, 0].max
        
        @cash_register.lock! # Prevent race conditions
        @cash_register.amount = (@cash_register.amount || 0) + cash_paid
        @cash_register.save!
      end
      
      success = true
    end
    
    if success
       change = 0
       if params[:amount_tendered].present?
         tendered = params[:amount_tendered].to_s.gsub(',', '.').to_f
         to_pay = [final_total - voucher_amount, 0].max
         change = [tendered - to_pay, 0].max
       end
       
       notice_msg = "Transaction completed!"
       if payment_method == 'cash'
          notice_msg += " Change: #{helpers.number_to_currency(change)}"
       end
       
      redirect_to pos_path(@cash_register), notice: notice_msg
    else
      redirect_to pos_path(@cash_register), alert: @error_message || "Checkout failed."
    end
  end

  def add_free_price_item
    @article = Article.find(params[:article_id])
  end

  def save_free_price_item
    @article = Article.find(params[:article_id])
    price = params[:price].to_f
    
    # Requirement: "So if the same free type articles is added twice (with different amounts) it should be there twice"
    # To achieve this, we cannot use find_or_initialize_by(article: @article) because that aggregates same articles.
    # We must create a NEW line item for every addition of a free price item.
    
    @item = @order.order_items.build(article: @article)
    @item.quantity = 1
    @item.unit_price = price
    @item.gross_price = price
    @item.discount = 0
    @item.net_price = price
    @item.save!
    
    redirect_to pos_path(@cash_register, section_id: params[:section_id]), notice: "Added #{@article.name} at #{helpers.number_to_currency(price)}"
  end

  def withdraw_cash
    # Displays the form
  end

  def process_withdrawal
    amount = params[:amount].to_f
    reason = params[:reason]

    if amount <= 0
      redirect_to withdraw_cash_pos_path(@cash_register), alert: "Please enter a valid amount greater than 0."
      return
    end
    
    current_amount = @cash_register.amount || 0
    if amount > current_amount
      redirect_to withdraw_cash_pos_path(@cash_register), alert: "Cannot withdraw more than current balance (#{helpers.number_to_currency(current_amount)})."
      return
    end

    ActiveRecord::Base.transaction do
       @cash_register.lock!
       @cash_register.amount = (@cash_register.amount || 0) - amount
       @cash_register.save!
       
       Transaction.create!(
         transaction_type: 'removal',
         amount: amount,
         description: reason,
         user_name: current_user.name
       )

       unless reason.to_s.start_with?("Abschöpfen")
          debit = '6700'
          credit = '1000'
          tax = '0.0'
          
          if reason.to_s.start_with?("Handelswaren 2.6")
             debit = '4200'
             tax = '2.6'
          elsif reason.to_s.start_with?("Support")
             debit = '6700'
             tax = '0.0'
          elsif reason.to_s.start_with?("Handelswaren 8.1")
             debit = '4200'
             tax = '8.1'
          elsif reason.to_s.start_with?("Sonstiges 8.1")
             debit = '6700'
             tax = '8.1'
          else
             # Default
             debit = '6700'
             tax = '0.0'
          end
          
          Entry.create!(
             booking_date: Date.current,
             debit_account: debit,
             credit_account: credit,
             amount: amount,
             description: reason,
             tax_code: tax,
             reference_number: "Withdrawal"
          )
       end
    end
    
    redirect_to pos_path(@cash_register), notice: "Successfully withdrew #{helpers.number_to_currency(amount)}."
  end

  def park_order
    name = params[:name].presence || "#{ @cash_register.name } - #{ Time.current.strftime('%d.%m.%Y %H:%M') }"
    
    if @order.order_items.empty?
       redirect_to pos_path(@cash_register), alert: "Cannot park empty order."
       return
    end

    @order.update!(status: 'parked', name: name)
    
    redirect_to pos_path(@cash_register), notice: "Order parked as '#{name}'"
  end

  def restore_order
    order_to_restore = @cash_register.orders.parked.find(params[:order_id])
    
    if @order.order_items.any?
       redirect_to pos_path(@cash_register), alert: "Current order is not empty. Please clear or park it first."
       return
    end

    @order.destroy if @order.persisted?
    order_to_restore.update!(status: 'pending')
    
    redirect_to pos_path(@cash_register), notice: "Order '#{order_to_restore.name}' restored."
  end

  def update_item_discount
     @item = @order.order_items.find(params[:item_id])
     val = params[:discount_value].to_f
     type = params[:discount_type]
     
     gross = @item.gross_price || (@item.quantity * @item.unit_price) 
     # Ensure gross is set in DB if missing (legacy)
     @item.gross_price = gross
     
     discount_amount = 0
     if type == 'percent'
        discount_amount = (gross * (val / 100.0)).round(2)
     else
        discount_amount = val
     end
     
     discount_amount = [discount_amount, gross].min
     discount_amount = [discount_amount, 0].max
     
     net_price = gross - discount_amount
     
     # Round net_price to nearest 0.05
     net_price = (net_price * 20).round / 20.0
     
     # Adjust discount to match
     discount_amount = gross - net_price
     
     @item.discount = discount_amount
     @item.net_price = net_price
     @item.save!
     
     redirect_to pos_path(@cash_register, section_id: params[:section_id]), notice: "Discount updated for #{@item.article.name}"
  end

  private
    def set_register
      @cash_register = CashRegister.find(params[:id])
    end

    def set_current_order
      @order = @cash_register.orders.pending.first_or_create
    end
end
