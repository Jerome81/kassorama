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

    scope = Article.where(status: 'active').includes(:stocks, :article_category)
    scope = scope.where(supplier_id: @selected_supplier_id) if @selected_supplier_id.present?
    
    # Select articles matching criteria: Primary Stock < Sales 30d AND Other Locations Stock > 0
    @articles = scope.select do |article|
      sales_30d = @recent_sales[article.id] || 0
      
      # Stock in Primary
      primary_stock_record = article.stocks.find { |s| s.location_id == @primary_location.id }
      primary_qty = primary_stock_record&.quantity || 0

      # Stock in Others
      other_qty = 0
      @other_locations.each do |loc|
         st = article.stocks.find { |s| s.location_id == loc.id }
         other_qty += (st&.quantity || 0)
      end

      (primary_qty < sales_30d) && (other_qty > 0)
    end

    # Sort articles by Group then Name
    sorted_articles = @articles.sort_by do |article|
      [article.group.to_s, article.name]
    end

    # Group by category
    @grouped_articles = sorted_articles.group_by(&:article_category)
  end

  def create
    article = Article.find(params[:article_id])
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

    source_stock = article.stocks.find_or_initialize_by(location: source_location)
    current_source_qty = source_stock.quantity || 0
    
    if current_source_qty < quantity
      redirect_to stock_transfers_path(supplier_id: current_supplier_id), alert: "Not enough stock in #{source_location.name} (Available: #{current_source_qty})"
      return
    end

    ActiveRecord::Base.transaction do
      # Deduct from source
      source_stock.quantity = current_source_qty - quantity
      source_stock.save!
      
      # Add to primary
      primary_stock = article.stocks.find_or_initialize_by(location: primary_location)
      primary_stock.quantity = (primary_stock.quantity || 0) + quantity
      primary_stock.save!
    end

    redirect_to stock_transfers_path(supplier_id: current_supplier_id), notice: "Successfully moved #{quantity}x #{article.name} from #{source_location.name} to #{primary_location.name}"
  end
end
