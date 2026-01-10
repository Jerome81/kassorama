class InventoriesController < ApplicationController
  before_action :set_inventory, only: %i[ show edit update destroy complete update_line report ]

  # GET /inventories or /inventories.json
  def index
    @inventories = Inventory.all
  end

  # GET /inventories/1 or /inventories/1.json
  def show
    @active_articles = Article.where(status: 'active').order(:group, :name)
    @locations = Location.all.order(:name)
    # Pre-fetch existing lines for efficient access: { [article_id, location_id] => line }
    @inventory_lines = @inventory.inventory_lines.index_by { |line| [line.article_id, line.location_id] }
  end

  def update_line
    if @inventory.completed_at.present?
      head :forbidden
      return
    end

    # @inventory is set by before_action
    article = Article.find(params[:article_id])
    location = Location.find(params[:location_id])
    quantity = params[:quantity].to_i
    
    @line = @inventory.inventory_lines.find_or_initialize_by(article: article, location: location)
    
    # Calculate diff: accumulates the change from the original snapshot
    old_quantity = @line.quantity || 0
    delta = quantity - old_quantity
    
    @line.quantity = quantity
    @line.diff = (@line.diff || 0) + delta
    
    if @line.save
      # Also update the actual Stock record
      stock = Stock.find_or_initialize_by(article: article, location: location)
      stock.quantity = quantity
      stock.save!
      
      render json: { diff: @line.diff }, status: :ok
    else
      head :unprocessable_entity
    end
  end

  def complete
    if @inventory.update(completed_at: Time.current)
      redirect_to @inventory, notice: "Inventory marked as completed."
    else
      redirect_to @inventory, alert: "Failed to complete inventory."
    end
  end

  def report
    require "prawn"
    require "prawn/table"

    pdf = Prawn::Document.new
    pdf.text "Inventory Report: #{@inventory.name}", size: 20, style: :bold
    pdf.text "Generated on: #{Time.current.strftime('%d.%m.%Y %H:%M')}", size: 10
    pdf.move_down 20

    active_articles = Article.where(status: 'active').order(:group, :name)
    inventory_lines = @inventory.inventory_lines.group_by(&:article_id)

    table_data = [["Article", "Quantity", "Cost", "Total Value"]]
    grand_total = 0

    active_articles.each do |article|
      lines = inventory_lines[article.id] || []
      total_quantity = lines.sum(&:quantity)
      cost = article.cost || 0
      total_value = total_quantity * cost
      
      grand_total += total_value

      table_data << [
        "#{article.group.present? ? "[#{article.group}] " : ""}#{article.name}",
        total_quantity.to_s,
        helpers.number_to_currency(cost, unit: ''),
        helpers.number_to_currency(total_value, unit: '')
      ]
    end

    table_data << ["", "", "Grand Total", helpers.number_to_currency(grand_total, unit: '')]

    pdf.table(table_data, header: true, width: pdf.bounds.width) do
      row(0).font_style = :bold
      column(1).align = :right
      column(2).align = :right
      column(3).align = :right
      row(-1).font_style = :bold
      row(-1).background_color = "f0f0f0"
    end

    send_data pdf.render, filename: "inventory_report_#{@inventory.id}.pdf", type: "application/pdf", disposition: "inline"
  end

  # GET /inventories/new
  def new
    @inventory = Inventory.new
  end

  # GET /inventories/1/edit
  def edit
  end

  # POST /inventories or /inventories.json
  def create
    @inventory = Inventory.new(inventory_params)

    respond_to do |format|
      if @inventory.save
        format.html { redirect_to @inventory, notice: "Inventory was successfully created." }
        format.json { render :show, status: :created, location: @inventory }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @inventory.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /inventories/1 or /inventories/1.json
  def update
    respond_to do |format|
      if @inventory.update(inventory_params)
        format.html { redirect_to @inventory, notice: "Inventory was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @inventory }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @inventory.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /inventories/1 or /inventories/1.json
  def destroy
    @inventory.destroy!

    respond_to do |format|
      format.html { redirect_to inventories_path, notice: "Inventory was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_inventory
      @inventory = Inventory.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def inventory_params
      params.require(:inventory).permit(:name)
    end
end
