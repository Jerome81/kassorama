class SectionsController < ApplicationController
  before_action :set_section

  def edit
    @articles = @section.articles.includes(:article_sections).order("article_sections.sort_order ASC")
    if params[:search_query].present?
      @search_results = Article.where("sku LIKE ?", "%#{params[:search_query]}%")
    end
  end

  def reorder
    params[:article_ids].each_with_index do |id, index|
      # We update the ArticleSection joining table
      # Find specific connection
      # Since article can be in multiple sections, we scope by section_id
      link = ArticleSection.find_by(section_id: @section.id, article_id: id)
      link.update(sort_order: index + 1) if link
    end
    head :ok
  end

  def update
    if @section.update(section_params)
      redirect_to edit_section_path(@section), notice: "Section updated."
    else
      render :edit
    end
  end

  def add_article
    if params[:article_id].present?
      article = Article.find(params[:article_id])
      add_single_article(article)
      return
    end

    query = params[:query]
    
    # 1. Exact Barcode -> Instant Add
    if (article = Article.find_by(barcode: query))
      add_single_article(article)
      return
    end
    
    # 2. Partial SKU Search
    articles = Article.where("sku LIKE ?", "%#{query}%")
    
    if articles.count == 1
      add_single_article(articles.first)
    elsif articles.count > 1
      redirect_to edit_section_path(@section, search_query: query)
    else
      flash[:alert] = "Article not found"
      redirect_to edit_section_path(@section)
    end
  end

  def remove_article
    article = Article.find(params[:article_id])
    @section.articles.delete(article)
    redirect_to edit_section_path(@section), notice: "Removed #{article.name}"
  end

  private

    def add_single_article(article)
      unless @section.articles.include?(article)
        @section.articles << article
        flash[:notice] = "Added #{article.name}"
      else
        flash[:alert] = "Article already in section"
      end
      
      if params[:search_query].present?
        redirect_to edit_section_path(@section, search_query: params[:search_query])
      else
        redirect_to edit_section_path(@section)
      end
    end

    def set_section
      @section = Section.find(params[:id])
    end

    def section_params
      params.require(:section).permit(:name)
    end
end
