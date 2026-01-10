class StockOrdersController < ApplicationController
  def index
    # Identify Primary Location (from first cash register)
    first_register = CashRegister.first
    @primary_location = first_register&.stock_location
    
    # If no register-linked location, fallback to first location
    @primary_location ||= Location.first
    
    # All locations
    @locations = Location.all
    if @primary_location
      # Ensure primary is first in the list for columns
      @other_locations = @locations.where.not(id: @primary_location.id)
      @sorted_locations = [@primary_location] + @other_locations
    else
      @sorted_locations = @locations
    end
    
    # Articles with stocks
    # We load all articles and their stocks
    @suppliers = Supplier.all.order(:name)
    @selected_supplier_id = params[:supplier_id]

    scope = Article.where(status: 'active').includes(:stocks, :article_category)
    scope = scope.where(supplier_id: @selected_supplier_id) if @selected_supplier_id.present?
    
    @articles = scope

    # Preload sales data for the last 30 days
    @recent_sales = OrderItem.joins(:order)
                             .where(orders: { updated_at: 30.days.ago.beginning_of_day..Time.current, status: 'completed' })
                             .group(:article_id)
                             .sum(:quantity)
    
    # Sort articles by Group then Name (standard display order)
    # Previous sort was by stock quantity, but user requested Group/Name ordering.
    sorted_articles = @articles.sort_by do |article|
      [article.group.to_s, article.name]
    end

    # Group by category (order of groups determined by first appearance in sorted list, roughly "most urgent category first")
    @grouped_articles = sorted_articles.group_by(&:article_category)
  end
end
