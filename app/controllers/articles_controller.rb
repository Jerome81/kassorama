class ArticlesController < ApplicationController
  before_action :set_article, only: %i[ show edit update destroy ]

  def index
    @articles = Article.all.order(:group, :name)
  end

  def show
  end

  def new
    @article = Article.new
    @article.tax_code = TaxCode.find_by(rate: 8.1)
  end

  def edit
  end

  def create
    @article = Article.new(article_params)

    if @article.save
      redirect_to article_url(@article), notice: "Article was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @article.update(article_params)
      redirect_to params[:return_to] || articles_url, notice: "Article was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @article.destroy!

    redirect_to articles_url, notice: "Article was successfully destroyed."
  end

  private
    def set_article
      @article = Article.find(params[:id])
    end

    def article_params
      params.require(:article).permit(:name, :sku, :barcode, :price, :cost, :tax_code_id, :group, :picture, :status, :price_type, :is_voucher, :article_category_id, :supplier_id, :booking_account)
    end
end
