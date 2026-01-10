class ArticleStatsController < ApplicationController
  def index
    @categories_data = []
    range = 30.days.ago.beginning_of_day..Time.current.end_of_day
    
    # 1. Categories with ID
    ArticleCategory.all.each do |cat|
        top_articles = get_top_articles_for_category(cat.id, range)
        if top_articles.any?
          total_rev = get_category_total_revenue(cat.id, range)
          @categories_data << { category_name: cat.name, articles: top_articles, total_revenue: total_rev } 
        end
    end

    # 2. Articles without category (nil)
    uncategorized = get_top_articles_for_category(nil, range)
    if uncategorized.any?
      total_rev = get_category_total_revenue(nil, range)
      @categories_data << { category_name: "Unkategorisiert", articles: uncategorized, total_revenue: total_rev } 
    end
  end

  private

  def get_top_articles_for_category(category_id, range)
    Article.joins(order_items: :order)
           .where(orders: { status: 'completed', created_at: range })
           .where(article_category_id: category_id)
           .group('articles.id')
           .select('articles.*, SUM(order_items.quantity) as total_quantity, SUM(order_items.quantity * order_items.unit_price) as total_revenue')
           .order('total_quantity DESC')
           .limit(10)
  end

  def get_category_total_revenue(category_id, range)
    Article.joins(order_items: :order)
           .where(orders: { status: 'completed', created_at: range })
           .where(article_category_id: category_id)
           .sum('order_items.quantity * order_items.unit_price')
  end
end
