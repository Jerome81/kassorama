class LocationsController < ApplicationController
  before_action :set_location, only: %i[ show edit update destroy ]

  # GET /locations or /locations.json
  def index
    @locations = Location.all
  end

  # GET /locations/1 or /locations/1.json
  def show
    if params[:search_query].present?
      @search_results = Article.where(status: 'active')
                         .where("barcode = ? OR sku = ? OR name LIKE ?", params[:search_query], params[:search_query], "%#{params[:search_query]}%")
                         .order(:name)
    end
    @stocks = @location.stocks.includes(:article).joins(:article).order('articles.name')
  end

  def add_stock
    @location = Location.find(params[:id])
    article = Article.find(params[:article_id])
    quantity_to_add = params[:quantity].to_i
    
    if quantity_to_add > 0
      stock = @location.stocks.find_or_initialize_by(article: article)
      stock.quantity = (stock.quantity || 0) + quantity_to_add
      stock.save!
      flash[:notice] = "Added #{quantity_to_add} to #{article.name}"
    else
      flash[:alert] = "Quantity must be greater than 0"
    end
    
    redirect_to location_path(@location)
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
