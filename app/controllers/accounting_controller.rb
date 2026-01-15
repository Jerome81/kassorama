class AccountingController < ApplicationController
  def index
    # Fetch completed orders that haven't been exported yet
    @orders = Order.where(status: 'completed', exported: nil)
                   .includes(order_items: [:article]) # Optimised loading
                   .order(created_at: :asc)

    # Group by day for the view
    @orders_by_day = @orders.group_by { |o| o.created_at.to_date }

    # Fetch unexported transactions
    @transactions = Transaction.where(exported: nil).order(created_at: :asc)
  end
  def create_booking
    date = Date.parse(params[:date])
    orders = Order.where(status: 'completed', exported: nil)
                  .where(created_at: date.beginning_of_day..date.end_of_day)
                  .includes(order_items: [:article])

    if orders.empty?
      redirect_to accounting_path, alert: "No orders found to book for #{date}."
      return
    end

    # Accumulators
    totals = {
      cash: { '8.1' => 0, '2.6' => 0, vouchers: 0, tip: 0, riddle: 0, poker: 0 },
      credit: { '8.1' => 0, '2.6' => 0, vouchers: 0, tip: 0, riddle: 0, poker: 0 }
    }

    orders.each do |order|
      payment_type = order.payment_method == 'cash' ? :cash : :credit
      
      order.order_items.each do |item|
        article = item.article
        line_total = item.quantity * item.unit_price

        # 8.1
        if article.tax_code&.rate == 8.1 && !article.name&.start_with?("Riddle")
           totals[payment_type]['8.1'] += line_total
        end
        
        # 2.6
        if article.tax_code&.rate == 2.6
           totals[payment_type]['2.6'] += line_total
        end
        
        # Vouchers
        if article.is_voucher
           totals[payment_type][:vouchers] += line_total
        end
        
        # Tip
        if article.name == "Trinkgeld"
           totals[payment_type][:tip] += line_total
        end

        # Riddle
        if article.name&.start_with?("Riddle")
           totals[payment_type][:riddle] += line_total
        end

        # Poker
        if article.name == "Poker buy in"
           totals[payment_type][:poker] += line_total
        end
      end
    end

    ActiveRecord::Base.transaction do
      # Create Entries
      totals.each do |payment_type, types|
        debit_account = payment_type == :cash ? "1000" : "1030"
        payment_suffix = payment_type == :cash ? "Bar" : "Kredit"

        types.each do |key, amount|
          next if amount <= 0

          entry_params = {
            booking_date: date,
            debit_account: debit_account,
            amount: amount,
            reference_number: "POS-#{date.strftime('%Y%m%d')}"
          }

          case key
          when '8.1'
            Entry.create!(entry_params.merge(
              tax_code: "8.1",
              credit_account: "3200",
              description: "Warenverkauf #{date.strftime('%d.%m.%Y')} 8.1 #{payment_suffix}"
            ))
          when '2.6'
            Entry.create!(entry_params.merge(
              tax_code: "2.6",
              credit_account: "3200",
              description: "Warenverkauf #{date.strftime('%d.%m.%Y')} 2.6 #{payment_suffix}"
            ))
          when :riddle
            Entry.create!(entry_params.merge(
              tax_code: "8.1", # Riddle tax code was specified as 8.1
              credit_account: "3410",
              description: "Besuche Riddle #{date.strftime('%d.%m.%Y')} #{payment_suffix}"
            ))
          when :poker
            Entry.create!(entry_params.merge(
              tax_code: "8.1",
              credit_account: "3415",
              description: "Poker buy in #{date.strftime('%d.%m.%Y')} #{payment_suffix}"
            ))
          when :tip
            Entry.create!(entry_params.merge(
              tax_code: "0.0",
              credit_account: "2150",
              description: "Trinkgeld #{date.strftime('%d.%m.%Y')} #{payment_suffix}"
            ))
          when :vouchers
             Entry.create!(entry_params.merge(
              tax_code: "0.0",
              credit_account: "2215",
              description: "Gutscheinverkauf #{date.strftime('%d.%m.%Y')} #{payment_suffix}"
            ))
          end
        end
      end

      # Mark orders as exported
      orders.update_all(exported: Time.current)
    end

    redirect_to accounting_path, notice: "Buchungen erfolgreich erstellt für #{date.strftime('%d.%m.%Y')}."
  end
  def create_transaction_booking
    transactions = Transaction.where(exported: nil)

    if transactions.empty?
      redirect_to accounting_path, alert: "No open transactions to book."
      return
    end

    ActiveRecord::Base.transaction do
      transactions.each do |transaction|
        description = transaction.description.to_s
        amount = transaction.amount
        date = transaction.created_at.to_date
        
        entry_params = {
          booking_date: date,
          amount: amount,
          description: description,
          reference_number: "TRANS-#{transaction.id}"
        }

        if transaction.transaction_type == 'removal'
          if description == "Abschöpfen"
             # Ignore entry creation
          elsif description.start_with?("Support")
             Entry.create!(entry_params.merge(
               tax_code: "0.0",
               debit_account: "6700",
               credit_account: "1000"
             ))
          elsif description.start_with?("Handelswaren 2.6")
             Entry.create!(entry_params.merge(
               tax_code: "2.6",
               debit_account: "4200",
               credit_account: "1000"
             ))
          elsif description.start_with?("Handelswaren 8.1")
             Entry.create!(entry_params.merge(
               tax_code: "8.1",
               debit_account: "4200",
               credit_account: "1000"
             ))
          elsif description.start_with?("Sonstiges 8.1")
             Entry.create!(entry_params.merge(
               tax_code: "8.1",
               debit_account: "6700",
               credit_account: "1000"
             ))
          else
             # Default
             Entry.create!(entry_params.merge(
               tax_code: "8.1",
               debit_account: "6700",
               credit_account: "1000"
             ))
          end
        elsif transaction.transaction_type == 'reconciliation'
           Entry.create!(entry_params.merge(
             tax_code: "0.0",
             debit_account: "1000",
             credit_account: "1098"
           ))
        end
      end
      
      # Mark ALL processed transactions as exported
      transactions.update_all(exported: Time.current)
    end

    redirect_to accounting_path, notice: "Transaktionen erfolgreich verbucht."
  end

  def settings
    @client_id = Setting[:bexio_client_id]
    @client_secret = Setting[:bexio_client_secret]
    @bexio_accounts = BexioAccount.order(:account_number)
    @bexio_tax_codes = BexioTaxCode.order(:name)
  end

  # ... existing methods ...

  def import_accounts
    service = BexioService.new
    accounts = service.fetch_accounts
    
    count = 0
    ActiveRecord::Base.transaction do
      BexioAccount.delete_all # Optional: clear old cache or just update
      
      accounts.each do |acc|
        next unless acc['id'] && acc['account_no']
        
        BexioAccount.create!(
          bexio_id: acc['id'].to_s,
          account_number: acc['account_no'].to_s,
          name: acc['name']
        )
        count += 1
      end
    end
    
    redirect_to accounting_settings_path, notice: "Successfully imported #{count} accounts from Bexio."
  rescue => e
    redirect_to accounting_settings_path, alert: "Import failed: #{e.message}"
  end

  def import_tax_codes
    service = BexioService.new
    taxes = service.fetch_taxes
    
    count = 0
    ActiveRecord::Base.transaction do
      BexioTaxCode.delete_all
      taxes.each do |tax|
        next unless tax['id'] && tax['code']
        
        BexioTaxCode.create!(
          bexio_id: tax['id'].to_s,
          name: tax['code']
        )
        count += 1
      end
    end
    
    redirect_to accounting_settings_path, notice: "Successfully imported #{count} tax codes from Bexio."
  rescue => e
    redirect_to accounting_settings_path, alert: "Import failed: #{e.message}"
  end
end
