class StockTransfersController < ApplicationController
  def index
    # Identify Primary Location (from first cash register)
    first_register = CashRegister.first
    @primary_location = first_register&.stock_location || Location.first

    # All locations
    @locations = Location.all.to_a
    @sorted_locations = @locations

    @source_location = if params[:source_location_id].present?
                         @locations.find { |l| l.id == params[:source_location_id].to_i }
                       end
    @source_location ||= @locations.first

    @target_location = if params[:target_location_id].present?
                         @locations.find { |l| l.id == params[:target_location_id].to_i }
                       end
    if @target_location.nil? || (@source_location && @target_location.id == @source_location.id)
      @target_location = @locations.find { |l| l.id != @source_location&.id } || @locations.second || @locations.first
    end

    # Preload sales data for the last 30 days
    @recent_sales = OrderItem.joins(:order)
                             .where(orders: { updated_at: 30.days.ago.beginning_of_day..Time.current, status: 'completed' })
                             .group(:article_id)
                             .sum(:quantity)

    # Filter Articles
    @suppliers = Supplier.all.order(:name)
    @selected_supplier_id = params[:supplier_id]

    scope = Article.where(status: 'active').includes(:stocks, :article_category, variants: [:stocks])
    scope = scope.where(supplier_id: @selected_supplier_id) if @selected_supplier_id.present?

    # Preload variant sales
    @recent_variant_sales = OrderItem.joins(:order)
                                     .where(orders: { updated_at: 30.days.ago.beginning_of_day..Time.current, status: 'completed' })
                                     .where.not(variant_id: nil)
                                     .group(:variant_id)
                                     .sum(:quantity)

    # Select articles matching criteria:
    # 1. Article Global: (Target available <= 0 OR Target available < Sales 30d) AND Source Location has stock
    # OR
    # 2. Variant Specific: (Variant Target <= 0 OR Variant Target < Variant Sales 30d) AND Variant has stock in Source Location
    @recommended_articles = if @source_location && @target_location && @source_location.id != @target_location.id
      scope.select do |article|
        # --- Article Level Check (Aggregated) ---
        global_sales_30d = @recent_sales[article.id] || 0

        # Sum all stock for this article (including variants)
        global_target_qty = article.stocks.select { |s| s.location_id == @target_location.id }.sum { |s| s.quantity || 0 }
        global_source_qty = article.stocks.select { |s| s.location_id == @source_location.id }.sum { |s| s.quantity || 0 }

        article_needs_stock = (global_target_qty <= 0 || global_target_qty < global_sales_30d) && (global_source_qty > 0)

        # --- Variant Level Check ---
        variant_needs_stock = false
        if article.variants.any?
          variant_needs_stock = article.variants.any? do |v|
            v_sales = @recent_variant_sales[v.id] || 0
            v_target = v.stocks.find { |s| s.location_id == @target_location.id }&.quantity || 0
            v_source = v.stocks.find { |s| s.location_id == @source_location.id }&.quantity || 0

            (v_target <= 0 || v_target < v_sales) && (v_source > 0)
          end
        end

        article_needs_stock || variant_needs_stock
      end
    else
      []
    end

    # Group Recommended
    @grouped_recommended = @recommended_articles.sort_by(&:name).group_by(&:article_category)

    # Group All
    @grouped_all = scope.sort_by(&:name).group_by(&:article_category)
  end

  def create
    article = Article.find(params[:article_id])
    variant_id = params[:variant_id]
    quantity = params[:quantity].to_i
    source_location = Location.find(params[:source_location_id])
    target_location = if params[:target_location_id].present?
                        Location.find(params[:target_location_id])
                      else
                        first_register = CashRegister.first
                        first_register&.stock_location || Location.where.not(id: source_location.id).first || Location.first
                      end

    current_supplier_id = params[:supplier_id]
    redirect_params = {
      supplier_id: current_supplier_id,
      source_location_id: source_location.id,
      target_location_id: target_location.id
    }

    if quantity <= 0
      redirect_to stock_transfers_path(redirect_params), alert: "Menge muss grösser als 0 sein"
      return
    end

    if source_location.id == target_location.id
      redirect_to stock_transfers_path(redirect_params), alert: "Start- und Ziellagerort dürfen nicht identisch sein"
      return
    end

    if variant_id.present?
      variant = Variant.find(variant_id)
      source_stock = article.stocks.find_or_initialize_by(location: source_location, variant: variant)
      target_stock = article.stocks.find_or_initialize_by(location: target_location, variant: variant)
      item_name = "#{article.name} - #{variant.name}"
    else
      source_stock = article.stocks.find_or_initialize_by(location: source_location, variant: nil)
      target_stock = article.stocks.find_or_initialize_by(location: target_location, variant: nil)
      item_name = article.name
    end

    current_source_qty = source_stock.quantity || 0

    if current_source_qty < quantity
      redirect_to stock_transfers_path(redirect_params), alert: "Nicht genügend Bestand für #{item_name} in #{source_location.name} (Verfügbar: #{current_source_qty})"
      return
    end

    ActiveRecord::Base.transaction do
      # Deduct from source
      source_stock.quantity = current_source_qty - quantity
      source_stock.save!

      # Add to target
      target_stock.quantity = (target_stock.quantity || 0) + quantity
      target_stock.save!
    end

    redirect_to stock_transfers_path(redirect_params), notice: "#{quantity}x #{item_name} erfolgreich von #{source_location.name} nach #{target_location.name} verschoben"
  end
end
