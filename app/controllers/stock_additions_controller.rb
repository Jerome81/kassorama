class StockAdditionsController < ApplicationController
  def index
    session[:stock_addition_article_ids] ||= []
    session[:stock_addition_article_ids].map!(&:to_i)

    if params[:clear].present?
      session[:stock_addition_article_ids] = []
    end

    if params[:remove_article_id].present?
      session[:stock_addition_article_ids].delete(params[:remove_article_id].to_i)
    end

    if params[:add_article_id].present?
      article = Article.find_by(id: params[:add_article_id], status: 'active')
      if article && !session[:stock_addition_article_ids].include?(article.id)
        session[:stock_addition_article_ids] << article.id
      end
    end

    if params[:search_query].present?
      query = params[:search_query].strip
      articles_by_self = Article.where(status: 'active')
                                .where("barcode = ? OR sku = ? OR name LIKE ?", query, query, "%#{query}%")
                                .includes(:variants)

      articles_by_variant = Article.where(status: 'active')
                                   .joins(:variants)
                                   .where("variants.barcode = ? OR variants.name LIKE ?", query, "%#{query}%")
                                   .includes(:variants)

      results = (articles_by_self + articles_by_variant).uniq.sort_by(&:name)

      exact_matches = results.select do |a|
        a.barcode == query || a.sku == query || a.variants.any? { |v| v.barcode == query }
      end

      if exact_matches.size == 1
        matched_article = exact_matches.first
        unless session[:stock_addition_article_ids].include?(matched_article.id)
          session[:stock_addition_article_ids] << matched_article.id
        end
        @search_results = []
      elsif results.size == 1
        matched_article = results.first
        unless session[:stock_addition_article_ids].include?(matched_article.id)
          session[:stock_addition_article_ids] << matched_article.id
        end
        @search_results = []
      else
        @search_results = results
        @no_results = results.empty?
      end
    end

    @locations = Location.all
    added_ids = session[:stock_addition_article_ids]
    articles_by_id = Article.where(id: added_ids, status: 'active')
                            .includes(:stocks, variants: :stocks)
                            .index_by(&:id)
    @added_articles = added_ids.filter_map { |id| articles_by_id[id] }
  end

  def create
    quantities = params[:quantities] || {}
    variant_quantities = params[:variant_quantities] || {}
    added_any = false

    ActiveRecord::Base.transaction do
      quantities.each do |article_id, location_map|
        next unless location_map.respond_to?(:each)

        article = Article.find(article_id)
        location_map.each do |location_id, qty_val|
          qty = qty_val.to_i
          next unless qty > 0

          location = Location.find(location_id)
          stock = Stock.find_or_initialize_by(article: article, variant: nil, location: location)
          stock.quantity = (stock.quantity || 0) + qty
          stock.save!
          added_any = true
        end
      end

      variant_quantities.each do |variant_id, location_map|
        next unless location_map.respond_to?(:each)

        variant = Variant.find(variant_id)
        article = variant.article
        location_map.each do |location_id, qty_val|
          qty = qty_val.to_i
          next unless qty > 0

          location = Location.find(location_id)
          stock = Stock.find_or_initialize_by(article: article, variant: variant, location: location)
          stock.quantity = (stock.quantity || 0) + qty
          stock.save!
          added_any = true
        end
      end
    end

    if added_any
      session[:stock_addition_article_ids] = []
      redirect_to stock_additions_path, notice: "Waren wurden erfolgreich hinzugefügt."
    else
      redirect_to stock_additions_path, alert: "Menge muss grösser als 0 sein"
    end
  end
end

