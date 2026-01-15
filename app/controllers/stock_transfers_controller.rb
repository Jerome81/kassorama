class StockTransfersController < ApplicationController
  def index
    # Identify Primary Location (from first cash register)
    first_register = CashRegister.first
    @primary_location = first_register&.stock_location || Location.first
    
    # All locations
    @locations = Location.all
    if @primary_location
      # Ensure primary is first in the list for columns
      @other_locations = @locations.where.not(id: @primary_location.id)
      @sorted_locations = [@primary_location] + @other_locations
    else
      @sorted_locations = @locations
      @other_locations = []
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
    # 1. Article Global: Primary available < Sales 30d AND Other Locations have stock
    # OR
    # 2. Variant Specific: Variant Primary < Variant Sales 30d AND Variant has stock in others
    @recommended_articles = scope.select do |article|
      # --- Article Level Check (Aggregated) ---
      global_sales_30d = @recent_sales[article.id] || 0
      
      # Sum all stock for this article (including variants)
      global_primary_qty = article.stocks.select { |s| s.location_id == @primary_location.id }.sum { |s| s.quantity || 0 }

      global_other_qty = 0
      @other_locations.each do |loc|
         qty = article.stocks.select { |s| s.location_id == loc.id }.sum { |s| s.quantity || 0 }
         global_other_qty += qty
      end
      
      article_needs_stock = (global_primary_qty < global_sales_30d) && (global_other_qty > 0)

      # --- Variant Level Check ---
      variant_needs_stock = false
      if article.variants.any? # Don't need to load if already loaded in includes
         variant_needs_stock = article.variants.any? do |v|
            v_sales = @recent_variant_sales[v.id] || 0
            v_primary = v.stocks.find { |s| s.location_id == @primary_location.id }&.quantity || 0
            
            v_other_qty = 0
            @other_locations.each do |loc|
               st = v.stocks.find { |s| s.location_id == loc.id }
               v_other_qty += (st&.quantity || 0)
            end
            
            (v_primary < v_sales) && (v_other_qty > 0)
         end
      end

      article_needs_stock || variant_needs_stock
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
    
    # Identify Primary Location
    first_register = CashRegister.first
    primary_location = first_register&.stock_location || Location.first

    current_supplier_id = params[:supplier_id]

    if quantity <= 0
      redirect_to stock_transfers_path(supplier_id: current_supplier_id), alert: "Quantity must be greater than 0"
      return
    end

    if source_location.id == primary_location.id
      redirect_to stock_transfers_path(supplier_id: current_supplier_id), alert: "Cannot transfer from primary location to itself"
      return
    end

    if variant_id.present?
       variant = Variant.find(variant_id)
       source_stock = article.stocks.find_or_initialize_by(location: source_location, variant: variant)
       
       primary_stock = article.stocks.find_or_initialize_by(location: primary_location, variant: variant)
       item_name = "#{article.name} - #{variant.name}"
    else
       source_stock = article.stocks.find_or_initialize_by(location: source_location, variant: nil)
       primary_stock = article.stocks.find_or_initialize_by(location: primary_location, variant: nil)
       item_name = article.name
    end

    current_source_qty = source_stock.quantity || 0
    
    if current_source_qty < quantity
      redirect_to stock_transfers_path(supplier_id: current_supplier_id), alert: "Not enough stock for #{item_name} in #{source_location.name} (Available: #{current_source_qty})"
      return
    end

    ActiveRecord::Base.transaction do
      # Deduct from source
      source_stock.quantity = current_source_qty - quantity
      source_stock.save!
      
      # Add to primary
      primary_stock.quantity = (primary_stock.quantity || 0) + quantity
      primary_stock.save!
    end

    redirect_to stock_transfers_path(supplier_id: current_supplier_id), notice: "Successfully moved #{quantity}x #{item_name} from #{source_location.name} to #{primary_location.name}"
  end
end
