class PosController < ApplicationController
  before_action :set_register, only: [:show, :add_item, :add_variant_item, :checkout, :update_item_quantity, :remove_item, :payment, :process_payment, :abort_payment, :print_receipt, :add_free_price_item, :save_free_price_item, :withdraw_cash, :process_withdrawal, :park_order, :restore_order, :update_item_discount]
  before_action :set_current_order, only: [:show, :add_item, :add_variant_item, :checkout, :update_item_quantity, :remove_item, :payment, :process_payment, :save_free_price_item, :park_order, :restore_order, :update_item_discount]

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
      articles = Article.where(status: 'active').left_joins(:variants).where("articles.name LIKE :query OR variants.name LIKE :query", query: "%#{params[:search_query]}%").distinct if articles.empty?
      
      @articles = articles.order(:name)
      flash.now[:notice] = "#{@articles.count} Ergebnisse für '#{params[:search_query]}' gefunden" if @articles.any?
    elsif @active_section
      # Fetch articles manually assigned to the section as well as articles in a matching category
      matching_category_ids = ArticleCategory.where("LOWER(TRIM(name)) = LOWER(TRIM(?))", @active_section.name.to_s).pluck(:id)

      join_sql = ActiveRecord::Base.sanitize_sql_array([
        "LEFT JOIN article_sections ON article_sections.article_id = articles.id AND article_sections.section_id = ?",
        @active_section.id
      ])

      scope = Article.where(status: 'active').joins(join_sql)
      if matching_category_ids.any?
        scope = scope.where(
          "article_sections.section_id = :section_id OR articles.article_category_id IN (:category_ids)",
          section_id: @active_section.id,
          category_ids: matching_category_ids
        )
      else
        scope = scope.where("article_sections.section_id = ?", @active_section.id)
      end

      @articles = scope.distinct
                       .order(Arel.sql("CASE WHEN article_sections.sort_order IS NULL THEN 1 ELSE 0 END ASC, article_sections.sort_order ASC, articles.name ASC"))
    else
      @articles = Article.where(status: 'active').order(:name)
    end
  end

  def add_item
    query = params[:query]
    
    # Check if there is a variant match mainly for barcode
    variant = Variant.find_by(barcode: query)
    if variant
      add_variant_logic(variant)
      return
    end

    # Prioritized Search:
    # 1. Barcode (exact)
    # 2. SKU (exact)
    # 3. Name (partial)
    
    articles = Article.where(status: 'active').where(barcode: query)
    articles = Article.where(status: 'active').where(sku: query) if articles.empty?
    articles = Article.where(status: 'active').left_joins(:variants).where("articles.name LIKE :query OR variants.name LIKE :query", query: "%#{query}%").distinct if articles.empty?
    
    if articles.count == 1
      article = articles.first
      
      # Check for variants
      if article.variants.any?
        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.append("modal-container", partial: "pos/variant_selection_modal", locals: { article: article }) }
          format.html { redirect_to pos_path(@cash_register), alert: "Bitte wählen Sie eine Variante." }
        end
        return
      end

      if article.price_type == 'free'
        redirect_to add_free_price_item_pos_path(@cash_register, article_id: article.id, section_id: params[:section_id])
      else
        @item = @order.order_items.find_or_initialize_by(article: article, variant: nil)
        @item.quantity = (@item.quantity || 0) + 1
        @item.unit_price = article.price
        @item.gross_price = @item.quantity * @item.unit_price
        @item.discount = 0
        @item.net_price = @item.gross_price
        @item.save!
        flash[:notice] = "#{article.name} hinzugefügt"
        redirect_to pos_path(@cash_register, section_id: params[:section_id])
      end
    elsif articles.count > 1
      # Redirect to show action with search results
      redirect_to pos_path(@cash_register, section_id: params[:section_id], search_query: query)
    else
      flash[:alert] = "Artikel nicht gefunden"
      redirect_to pos_path(@cash_register, section_id: params[:section_id])
    end
  end

  def add_variant_item
    variant = Variant.find(params[:variant_id])
    add_variant_logic(variant)
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
    
    # If order is empty, clear the name
    if @order.order_items.empty?
      @order.update(name: nil)
    end
    
    redirect_to pos_path(@cash_register, section_id: params[:section_id])
  end

  def remove_item
    @item = @order.order_items.find(params[:item_id])
    @item.destroy
    
    if @order.order_items.empty?
      @order.update(name: nil)
    end
    
    redirect_to pos_path(@cash_register, section_id: params[:section_id]), notice: "#{@item.article.name} entfernt"
  end

  def payment
    @order_items = @order.order_items.includes(:article, :variant)
    @total = @order_items.sum { |item| item.net_price || (item.quantity * item.unit_price) }
    @tip_article = Article.find_by(barcode: 'tip')
  end

  def process_payment
    if @order.order_items.empty?
      respond_to do |format|
        format.json { render json: { success: false, result_message: "Warenkorb ist leer", redirect_url: pos_path(@cash_register) }, status: :unprocessable_entity }
        format.html { redirect_to pos_path(@cash_register), alert: "Warenkorb ist leer" }
      end
      return
    end

    stock_location = @cash_register.stock_location
    
    unless stock_location
      msg = "Diese Kasse ist keinem Lagerort zugewiesen. Bitte kontaktieren Sie den Administrator."
      respond_to do |format|
        format.json { render json: { success: false, result_message: msg, redirect_url: pos_path(@cash_register) }, status: :unprocessable_entity }
        format.html { redirect_to pos_path(@cash_register), alert: msg }
      end
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
       voucher_info = [voucher_info, "Betrag: #{helpers.number_to_currency(voucher_amount)}"].compact.join(" - ")
    end

    print "Payment:", payment_method, "\n"
    print "Terminal IP:", @cash_register.terminal_ip, "\n"
    print "Terminal Port:", @cash_register.terminal_port, "\n"
    print "Final total:", final_total, "\n"
    card_amount = [final_total - voucher_amount, 0.0].max.round(2)
    if payment_method == 'card' && @cash_register.terminal_ip.present? && card_amount > 0
      print "Kontaktiere Kreditkarten Terminal at :", @cash_register.terminal_ip, ":", @cash_register.terminal_port, "\n"
      begin
        TerminaloramaClient.pay(
          ip: @cash_register.terminal_ip,
          port: @cash_register.terminal_port,
          amount: card_amount,
          currency: "CHF",
          reference_number: "ORDER-#{@order.id}"
        )
      rescue TerminaloramaClient::PaymentError => e
        respond_to do |format|
          format.json do
            render json: {
              success: false,
              result_code: e.result_code,
              overall_result: e.overall_result,
              result_message: e.message,
              redirect_url: payment_pos_path(@cash_register)
            }, status: :unprocessable_entity
          end
          format.html { redirect_to payment_pos_path(@cash_register), alert: e.message }
        end
        return
      end
    end

    success = false
    begin
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
            stock = Stock.find_or_initialize_by(article: item.article, variant: item.variant, location: stock_location)
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
    rescue StandardError => e
      @error_message = "#{e.message}"
      Rails.logger.error("Checkout Error: #{e.message}\n#{e.backtrace.join("\n")}")
      success = false
    end
    
    if success
       to_pay = [final_total - voucher_amount, 0].max.round(2)
       tendered = to_pay
       change = 0.0
       if params[:amount_tendered].present?
         tendered = params[:amount_tendered].to_s.gsub(',', '.').to_f
         change = [tendered - to_pay, 0].max.round(2)
       end
       
       notice_msg = "Transaktion abgeschlossen!"
       if payment_method == 'cash'
          notice_msg += " Rückgeld: #{helpers.number_to_currency(change)}"
          PrinterClient.try_open_drawer(@cash_register)
       end

       receipt_items = @order.order_items.includes({ article: :tax_code }, :variant).map do |item|
         gross = (item.gross_price || (item.quantity * item.unit_price)).to_f.round(2)
         disc = item.discount.to_f.round(2)
         net = (item.net_price || (gross - disc)).to_f.round(2)
         {
           name: item.article.name,
           variant: item.variant&.name,
           quantity: item.quantity,
           unit_price: item.unit_price.to_f.round(2),
           gross_price: gross,
           discount: disc,
           total_amount: net,
           tax_code: item.article.tax_code&.rate.to_f
         }
       end

       receipt_data = {
         order_id: @order.id,
         order_name: @order.name,
         cash_register: @cash_register.name,
         cashier: current_user&.name,
         timestamp: Time.current.strftime("%d.%m.%Y %H:%M"),
         currency: "CHF",
         payment_method: payment_method,
         subtotal: total_gross.to_f.round(2),
         total_discount: discount_amount.to_f.round(2),
         voucher_amount: voucher_amount.to_f.round(2),
         voucher_code: params[:voucher_code].to_s,
         total_amount: to_pay,
         amount_tendered: tendered.to_f.round(2),
         change: change,
         items: receipt_items
       }
       
      respond_to do |format|
        format.json do
          flash[:notice] = notice_msg
          render json: {
            success: true,
            result_code: 0,
            result_message: notice_msg,
            redirect_url: pos_path(@cash_register),
            receipt_data: receipt_data
          }, status: :ok
        end
        format.html { redirect_to pos_path(@cash_register), notice: notice_msg }
      end
    else
      err_msg = @error_message || "Bezahlung fehlgeschlagen."
      respond_to do |format|
        format.json do
          render json: {
            success: false,
            result_code: -1,
            result_message: err_msg,
            redirect_url: pos_path(@cash_register)
          }, status: :unprocessable_entity
        end
        format.html { redirect_to pos_path(@cash_register), alert: err_msg }
      end
    end
  end

  def abort_payment
    unless @cash_register.terminal_ip.present?
      render json: {
        success: false,
        status: "error",
        result_code: -1,
        result_message: "Kein Kartenterminal für diese Kasse konfiguriert."
      }, status: :unprocessable_entity
      return
    end

    begin
      result = TerminaloramaClient.abort(
        ip: @cash_register.terminal_ip,
        port: @cash_register.terminal_port
      )
      render json: {
        success: true,
        status: result["status"] || "ok",
        overall_result: result["overall_result"] || "Success",
        result_code: result["result_code"] || 0,
        result_message: result["result_message"].presence || "Abbruchbefehl vom Terminal bestätigt"
      }, status: :ok
    rescue TerminaloramaClient::PaymentError => e
      render json: {
        success: false,
        status: "error",
        overall_result: e.overall_result || "Failure",
        result_code: e.result_code || -1,
        result_message: e.message
      }, status: :unprocessable_entity
    end
  end

  def print_receipt
    unless @cash_register.printer_ip.present?
      msg = "Kein Quittungsdrucker für diese Kasse konfiguriert."
      respond_to do |format|
        format.json do
          render json: {
            success: false,
            status: "error",
            result_message: msg
          }, status: :unprocessable_entity
        end
        format.html { redirect_back fallback_location: transactions_cash_register_path(@cash_register), alert: msg }
      end
      return
    end

    raw_receipt = params[:receipt_data]
    receipt_payload = if raw_receipt.respond_to?(:to_unsafe_h)
                        raw_receipt.to_unsafe_h
                      elsif raw_receipt.is_a?(Hash)
                        raw_receipt
                      elsif params[:order_id].present?
                        order = @cash_register.orders.find_by(id: params[:order_id])
                        order ? build_receipt_data_for_order(order) : {}
                      else
                        {}
                      end

    begin
      result = PrinterClient.print(
        ip: @cash_register.printer_ip,
        port: @cash_register.printer_port,
        receipt_data: receipt_payload
      )
      ok_msg = result["result_message"].presence || "Quittung erfolgreich gedruckt"
      respond_to do |format|
        format.json do
          render json: {
            success: true,
            status: result["status"] || "printed",
            result_message: ok_msg
          }, status: :ok
        end
        format.html { redirect_back fallback_location: transactions_cash_register_path(@cash_register), notice: ok_msg }
      end
    rescue PrinterClient::PrintError => e
      respond_to do |format|
        format.json do
          render json: {
            success: false,
            status: "error",
            result_message: e.message
          }, status: :unprocessable_entity
        end
        format.html { redirect_back fallback_location: transactions_cash_register_path(@cash_register), alert: e.message }
      end
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
    
    redirect_path = if params[:return_to] == 'payment'
                      payment_pos_path(@cash_register)
                    else
                      pos_path(@cash_register, section_id: params[:section_id])
                    end
    
    redirect_to redirect_path, notice: "#{@article.name} für #{helpers.number_to_currency(price)} hinzugefügt"
  end

  def withdraw_cash
    # Displays the form
  end

  def process_withdrawal
    amount = params[:amount].to_f
    reason = params[:reason]

    if amount <= 0
      redirect_to withdraw_cash_pos_path(@cash_register), alert: "Bitte geben Sie einen gültigen Betrag grösser als 0 ein."
      return
    end

    # Handle Transfer to another register
    if params[:target_register_id].present?
      target_register = CashRegister.find(params[:target_register_id])
      
      if amount > (@cash_register.amount || 0)
        redirect_to withdraw_cash_pos_path(@cash_register), alert: "Es kann nicht mehr als der aktuelle Kassenbestand übertragen werden."
        return
      end
      
      ActiveRecord::Base.transaction do
        @cash_register.lock!
        target_register.lock!
        
        @cash_register.amount = (@cash_register.amount || 0) - amount
        target_register.amount = (target_register.amount || 0) + amount
        
        @cash_register.save!
        target_register.save!
        
        # Log removal from source
        Transaction.create!(
          cash_register: @cash_register,
          transaction_type: 'transfer to',
          amount: amount,
          description: "Transfer nach #{target_register.name}",
          user_name: current_user.name
        )
        
        # Log addition to target
        Transaction.create!(
          cash_register: target_register,
          transaction_type: 'transfer from',
          amount: amount,
          description: "Transfer von #{@cash_register.name}",
          user_name: current_user.name
        )
      end
      
      PrinterClient.try_open_drawer(@cash_register)
      redirect_to pos_path(@cash_register), notice: "#{helpers.number_to_currency(amount)} erfolgreich an #{target_register.name} übertragen."
      return
    end
    
    current_amount = @cash_register.amount || 0
    if amount > current_amount
      redirect_to withdraw_cash_pos_path(@cash_register), alert: "Es kann nicht mehr als der aktuelle Kassenbestand (#{helpers.number_to_currency(current_amount)}) entnommen werden."
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
    
    PrinterClient.try_open_drawer(@cash_register)
    redirect_to pos_path(@cash_register), notice: "#{helpers.number_to_currency(amount)} erfolgreich entnommen."
  end

  def park_order
    if params[:target_order_id].present?
      target_order = @cash_register.orders.parked.find(params[:target_order_id])

      ActiveRecord::Base.transaction do
        @order.order_items.includes(:article).each do |item|
          if item.article&.price_type == 'free'
            item.update!(order_id: target_order.id)
          else
            existing_item = target_order.order_items.find_by(article_id: item.article_id, variant_id: item.variant_id)
            if existing_item
              existing_item.quantity = (existing_item.quantity || 0) + item.quantity
              existing_item.gross_price = existing_item.quantity * existing_item.unit_price
              existing_item.discount = (existing_item.discount || 0) + (item.discount || 0)
              existing_item.net_price = existing_item.gross_price - existing_item.discount
              existing_item.save!
              item.destroy!
            else
              item.update!(order_id: target_order.id)
            end
          end
        end

        @order.reload.destroy! if @order.persisted? && @order.id != target_order.id
        target_order.update!(status: 'pending')
      end

      redirect_to pos_path(@cash_register, section_id: params[:section_id]), notice: "Artikel zu '#{target_order.name}' hinzugefügt."
      return
    end

    name = params[:name].presence || "#{ @cash_register.name } - #{ Time.current.strftime('%d.%m.%Y %H:%M') }"
    
    if @order.order_items.empty?
       redirect_to pos_path(@cash_register), alert: "Leere Bestellung kann nicht parkiert werden."
       return
    end

    @order.update!(status: 'parked', name: name)
    
    redirect_to pos_path(@cash_register), notice: "Bestellung als '#{name}' parkiert"
  end

  def restore_order
    order_to_restore = @cash_register.orders.parked.find(params[:order_id])
    
    if @order.order_items.any?
       redirect_to pos_path(@cash_register), alert: "Aktuelle Bestellung ist nicht leer. Bitte zuerst leeren oder parkieren."
       return
    end

    @order.destroy if @order.persisted?
    order_to_restore.update!(status: 'pending')
    
    redirect_to pos_path(@cash_register), notice: "Bestellung '#{order_to_restore.name}' wiederhergestellt."
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
     
     redirect_to pos_path(@cash_register, section_id: params[:section_id]), notice: "Rabatt für #{@item.article.name} aktualisiert"
  end

  private
  
    def add_variant_logic(variant)
      @item = @order.order_items.find_or_initialize_by(article_id: variant.article_id, variant_id: variant.id)
      @item.quantity = (@item.quantity || 0) + 1
      # Use variant price/name (name is virtual on OrderItem usually, but we store article_id)
      # Price comes from variant
      @item.unit_price = variant.price
      @item.gross_price = @item.quantity * @item.unit_price
      @item.discount = 0
      @item.net_price = @item.gross_price
      @item.save!
      flash[:notice] = "#{variant.name} hinzugefügt"
      redirect_to pos_path(@cash_register, section_id: params[:section_id])
    end

    def set_register
      @cash_register = CashRegister.find(params[:id])
    end

    def set_current_order
      @order = @cash_register.orders.pending.first_or_create
    end

    def build_receipt_data_for_order(order)
      items = order.order_items.includes({ article: :tax_code }, :variant).map do |item|
        gross = (item.gross_price || (item.quantity * item.unit_price)).to_f.round(2)
        disc = item.discount.to_f.round(2)
        net = (item.net_price || (gross - disc)).to_f.round(2)
        {
          name: item.article.name,
          variant: item.variant&.name,
          quantity: item.quantity,
          unit_price: item.unit_price.to_f.round(2),
          gross_price: gross,
          discount: disc,
          total_amount: net,
          tax_code: item.article.tax_code&.rate.to_f
        }
      end

      subtotal = items.sum { |i| i[:gross_price] }.round(2)
      total_discount = (order.discount || items.sum { |i| i[:discount] }).to_f.round(2)

      voucher_amount = order.voucher_amount
      if voucher_amount <= 0
        voucher_amount = Entry.where(debit_account: '2215').where("reference_number LIKE ?", "#{order.id}/%").sum(:amount).to_f.round(2)
      end
      voucher_code = order.voucher_code

      net_total = (order.total_amount || items.sum { |i| i[:total_amount] }).to_f.round(2)
      to_pay = [net_total - voucher_amount, 0.0].max.round(2)
      ts = (order.updated_at || order.created_at || Time.current).strftime("%d.%m.%Y %H:%M")

      {
        order_id: order.id,
        order_name: order.name,
        cash_register: @cash_register.name,
        cashier: order.user_name.presence || current_user&.name,
        timestamp: ts,
        currency: "CHF",
        payment_method: order.payment_method.presence || "cash",
        subtotal: subtotal,
        total_discount: total_discount,
        voucher_amount: voucher_amount,
        voucher_code: voucher_code,
        total_amount: to_pay,
        amount_tendered: to_pay,
        change: 0.0,
        items: items
      }
    end
end
