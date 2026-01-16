class LocationsController < ApplicationController
  before_action :set_location, only: %i[ show edit update destroy ]

  # GET /locations or /locations.json
  def index
    @locations = Location.all
  end

  # GET /locations/1 or /locations/1.json
  def show
    if params[:search_query].present?
      query = params[:search_query]
      articles_by_self = Article.where(status: 'active')
                         .where("barcode = ? OR sku = ? OR name LIKE ?", query, query, "%#{query}%")
                         .includes(:variants)
      
      articles_by_variant = Article.where(status: 'active')
                            .joins(:variants)
                            .where("variants.barcode = ? OR variants.name LIKE ?", query, "%#{query}%")
                            .includes(:variants)
                            
      @search_results = (articles_by_self + articles_by_variant).uniq.sort_by(&:name)
    end
    @stocks = @location.stocks.includes(:article, :variant).joins(:article).order('articles.name')
  end

  def add_stock
    @location = Location.find(params[:id])
    article = Article.find(params[:article_id])
    variant_id = params[:variant_id]
    quantity_to_add = params[:quantity].to_i
    
    if quantity_to_add > 0
      if variant_id.present?
        variant = Variant.find(variant_id)
        stock = @location.stocks.find_or_initialize_by(article: article, variant: variant)
        item_name = "#{article.name} - #{variant.name}"
      else
        stock = @location.stocks.find_or_initialize_by(article: article, variant: nil)
        item_name = article.name
      end

      stock.quantity = (stock.quantity || 0) + quantity_to_add
      stock.save!
      flash[:notice] = "Added #{quantity_to_add} to #{item_name}"
    else
      flash[:alert] = "Quantity must be greater than 0"
    end
    
    redirect_to location_path(@location, search_query: params[:search_query])
  end

  # GET /locations/new
  def new
    @location = Location.new
  end

  # GET /locations/1/edit
  def edit
  end

  # POST /locations or /locations.json
  def create
    @location = Location.new(location_params)

    respond_to do |format|
      if @location.save
        format.html { redirect_to @location, notice: "Location was successfully created." }
        format.json { render :show, status: :created, location: @location }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @location.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /locations/1 or /locations/1.json
  def update
    respond_to do |format|
      if @location.update(location_params)
        format.html { redirect_to @location, notice: "Location was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @location }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @location.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /locations/1 or /locations/1.json
  def destroy
    @location.stocks.where(quantity: 0).destroy_all
    @location.destroy!

    respond_to do |format|
      format.html { redirect_to locations_path, notice: "Location was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_location
      @location = Location.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def location_params
      params.require(:location).permit(:name)
    end
end
