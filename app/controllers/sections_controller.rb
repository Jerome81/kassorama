class SectionsController < ApplicationController
  before_action :set_section

  def edit
    @articles = @section.articles
  end

  def update
    if @section.update(section_params)
      redirect_to edit_section_path(@section), notice: "Section updated."
    else
      render :edit
    end
  end

  def add_article
    query = params[:query]
    article = Article.find_by(barcode: query) || Article.find_by(sku: query)
    
    if article
      unless @section.articles.include?(article)
        @section.articles << article
        flash[:notice] = "Added #{article.name}"
      else
        flash[:alert] = "Article already in section"
      end
    else
      flash[:alert] = "Article not found"
    end
    
    redirect_to edit_section_path(@section)
  end

  def remove_article
    article = Article.find(params[:article_id])
    @section.articles.delete(article)
    redirect_to edit_section_path(@section), notice: "Removed #{article.name}"
  end

  private

    def set_section
      @section = Section.find(params[:id])
    end

    def section_params
      params.require(:section).permit(:name, :group_filter)
    end
end
