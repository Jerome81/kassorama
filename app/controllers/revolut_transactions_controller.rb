require 'csv'

class RevolutTransactionsController < ApplicationController
  def index
    @transactions = RevolutTransaction.where(exported: nil).order(date: :desc)
    @bexio_accounts = BexioAccount.all.order(:account_number)
    @bexio_tax_codes = BexioTaxCode.where(name: ['UR26', 'UN81', 'V00']).order(:name)
  end

  def import
    file = params[:file]
    if file.nil?
      redirect_to revolut_transactions_path, alert: "Please upload a CSV file."
      return
    end

    puts "*********************************"
    puts "File: #{file.path}"

    # Detect separator
    first_line = File.open(file.path, &:readline)
    separator = first_line.include?(';') ? ';' : ','
    puts "Detected separator: '#{separator}'"

    count = 0
    begin
      ActiveRecord::Base.transaction do
        # Use header_converters to handle potential BOM or whitespace in headers
        CSV.foreach(file.path, headers: true, col_sep: separator, header_converters: :symbol) do |row|
           # Map headers to symbols (lowercase, underscores)
           # "Date completed" -> :date_completed_utc
           # "Description" -> :description
           # "Payer" -> :payer
           # "Orig amount" -> :orig_amount
           # "Orig currency" -> :orig_currency
           # "Total amount" -> :total_amount

           # Access via symbols is safer with header_converters
           date_str = row[:date_completed_utc]
           
           # If nil, maybe the header converter didn't match exactly what we thought, fallback to string lookup if needed
           # But let's debug row keys if it fails.
           unless date_str.present?
             puts "Skipping row (missing date): #{row.inspect}" 
             next 
           end

           # Determine debit/credit account
           amount = row[:total_amount].to_f
           if amount >= 0
             debit_acc = "1021"
             credit_acc = nil
           else
             debit_acc = nil
             credit_acc = "1021"
           end

           RevolutTransaction.create!(
             date: Date.parse(date_str),
             description: row[:description],
             payer: row[:payer],
             original_amount: row[:orig_amount],
             original_currency: row[:orig_currency],
             total_amount: row[:total_amount],
             state: 'imported',
             debit_account: debit_acc,
             credit_account: credit_acc
           )
           count += 1
        end
      end
      redirect_to revolut_transactions_path, notice: "Successfully imported #{count} transactions."
    rescue => e
      puts "Import Error: #{e.message}"
      puts e.backtrace.join("\n")
      redirect_to revolut_transactions_path, alert: "Import failed: #{e.message}"
    end
  end

  def export
    transactions = RevolutTransaction.where(exported: nil)
                                     .where.not(debit_account: [nil, ''])
                                     .where.not(credit_account: [nil, ''])
                                     .where.not(tax_code: [nil, ''])

    count = 0
    errors = []
    service = BexioService.new
    
    transactions.each do |trans|
      begin
        line = {
          description: trans.description,
          amount: trans.total_amount.abs,
          debit_account: trans.debit_account,
          credit_account: trans.credit_account,
          tax_code: trans.tax_code
        }
        
        service.send_manual_entry(trans.date, trans.description, [line])
        
        trans.update!(exported: Date.today, state: 'exported')
        count += 1
      rescue => e
        errors << "Row #{trans.id}: #{e.message}"
      end
    end
    
    if errors.empty?
      redirect_to revolut_transactions_path, notice: "Successfully exported #{count} transactions to Bexio."
    else
      redirect_to revolut_transactions_path, alert: "Exported #{count} transactions. Errors: #{errors.join(', ')}"
    end
  end


  def update
    puts "DEBUG: RevolutTransactionsController#update called"
    puts "DEBUG: Params: #{params.inspect}"
    
    @transaction = RevolutTransaction.find(params[:id])
    if @transaction.update(transaction_params)
      puts "DEBUG: Update successful. New attributes: #{@transaction.attributes.inspect}"
      head :ok
    else
      puts "DEBUG: Update failed. Errors: #{@transaction.errors.full_messages}"
      render json: { errors: @transaction.errors.full_messages }, status: :unprocessable_entity
    end
  rescue => e
    puts "DEBUG: Exception in update: #{e.message}"
    puts e.backtrace.join("\n")
    render json: { error: e.message }, status: :internal_server_error
  end

  private

  def transaction_params
    params.require(:revolut_transaction).permit(:debit_account, :credit_account, :tax_code)
  end
end
