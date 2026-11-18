class InventoriesController < ApplicationController
  before_action :set_inventory, only: %i[ show edit update destroy complete update_line report ]

  # GET /inventories or /inventories.json
  def index
    @inventories = Inventory.all
  end

  # GET /inventories/1 or /inventories/1.json
  def show
    @active_articles = Article.where(status: 'active').includes(:variants).order(:name)
    @locations = Location.all.order(:name)
    # Pre-fetch existing lines for efficient access: { [article_id, variant_id, location_id] => line }
    @inventory_lines = {}
    @inventory.inventory_lines.order(:id).each do |line|
      key = [line.article_id, line.variant_id, line.location_id]
      if !@inventory_lines.key?(key) || line.diff.to_i != 0
        @inventory_lines[key] = line
      end
    end
  end

  def update_line
    if @inventory.completed_at.present?
      head :forbidden
      return
    end

    # @inventory is set by before_action
    article = Article.find(params[:article_id])
    location = Location.find(params[:location_id])
    variant_id = params[:variant_id]
    quantity = params[:quantity].to_i
    
    if variant_id.present?
       variant = Variant.find(variant_id)
       matching_lines = @inventory.inventory_lines.where(article: article, variant: variant, location: location).order(:id).to_a
       @line = matching_lines.find { |l| l.diff.to_i != 0 } || matching_lines.first || @inventory.inventory_lines.build(article: article, variant: variant, location: location)
       (matching_lines - [@line]).each(&:destroy)
       stock = Stock.find_or_initialize_by(article: article, variant: variant, location: location)
    else
       matching_lines = @inventory.inventory_lines.where(article: article, variant: nil, location: location).order(:id).to_a
       @line = matching_lines.find { |l| l.diff.to_i != 0 } || matching_lines.first || @inventory.inventory_lines.build(article: article, variant: nil, location: location)
       (matching_lines - [@line]).each(&:destroy)
       stock = Stock.find_or_initialize_by(article: article, variant: nil, location: location)
    end

    # Calculate diff: accumulates the change from the original snapshot
    old_quantity = @line.quantity || 0
    delta = quantity - old_quantity
    
    @line.quantity = quantity
    @line.diff = (@line.diff || 0) + delta
    
    @line.save!
    
    # Also update the actual Stock record
    stock.quantity = quantity
    stock.save!
    
    render json: { diff: @line.diff }, status: :ok
  end

  def complete
    if @inventory.update(completed_at: Time.current)
      redirect_to @inventory, notice: "Inventar als abgeschlossen markiert."
    else
      redirect_to @inventory, alert: "Inventar konnte nicht abgeschlossen werden."
    end
  end

  def report
    require "prawn"
    require "prawn/table"

    pdf = Prawn::Document.new(margin: 36)
    pdf.font "Courier"

    # Retro Arcade Header Banner
    banner_height = 76
    banner_top = pdf.cursor
    banner_width = pdf.bounds.width

    # Outer dark arcade box with double retro border
    pdf.fill_color "1A1A1A"
    pdf.fill_rectangle [0, banner_top], banner_width, banner_height
    pdf.stroke_color "FFD100"
    pdf.line_width = 3
    pdf.stroke_rectangle [0, banner_top], banner_width, banner_height
    pdf.line_width = 1
    pdf.stroke_rectangle [4, banner_top - 4], banner_width - 8, banner_height - 8

    # Corner pixel accents
    pdf.fill_color "FFD100"
    [[6, banner_top - 6], [banner_width - 12, banner_top - 6], [6, banner_top - banner_height + 12], [banner_width - 12, banner_top - banner_height + 12]].each do |px, py|
      pdf.fill_rectangle [px, py], 6, 6
    end

    # Draw an 8-bit Pixel Art Space Invader on the right side of the header
    invader_bitmap = [
      "  #     #  ",
      "   #   #   ",
      "  #######  ",
      " ## ### ## ",
      "###########",
      "# ####### #",
      "# #     # #",
      "   ## ##   "
    ]
    pixel_size = 4
    invader_origin_x = banner_width - (invader_bitmap.first.length * pixel_size) - 20
    invader_origin_y = banner_top - 22
    pdf.fill_color "FFD100"
    invader_bitmap.each_with_index do |row_str, row_idx|
      row_str.chars.each_with_index do |ch, col_idx|
        if ch == "#"
          pdf.fill_rectangle [invader_origin_x + (col_idx * pixel_size), invader_origin_y - (row_idx * pixel_size)], pixel_size, pixel_size
        end
      end
    end

    # Header text inside the arcade banner
    pdf.bounding_box([18, banner_top - 14], width: banner_width - 100) do
      pdf.fill_color "00E5FF"
      pdf.text ">>> KASSORAMA // 8-BIT INVENTORY SYSTEM <<<", size: 9, style: :bold
      pdf.move_down 4
      pdf.fill_color "FFD100"
      title_text = "Inventar: #{@inventory.name}"
      title_size = title_text.length > 34 ? 13 : 16
      pdf.text title_text, size: title_size, style: :bold
      pdf.move_down 4
      pdf.fill_color "E5E7EB"
      pdf.text "Erstellt am: #{Time.current.strftime('%d.%m.%Y %H:%M')}", size: 10
    end

    pdf.move_cursor_to(banner_top - banner_height - 16)

    # Retro pixel divider bar
    pdf.fill_color "2C2C2C"
    (0...(banner_width.to_i / 12)).each do |i|
      pdf.fill_color(i.even? ? "FFD100" : "2C2C2C")
      pdf.fill_rectangle [i * 12, pdf.cursor], 8, 4
    end
    pdf.move_down 14

    active_articles = Article.where(status: 'active').includes(:variants).order(:name)
    deduped_lines = {}
    @inventory.inventory_lines.order(:id).each do |line|
      key = [line.article_id, line.variant_id, line.location_id]
      if !deduped_lines.key?(key) || line.diff.to_i != 0
        deduped_lines[key] = line
      end
    end
    lines_by_article_and_variant = deduped_lines.values.group_by { |line| [line.article_id, line.variant_id] }

    table_data = [["Artikel", "Menge", "Einstandspreis", "Gesamtwert"]]
    total_cost = 0
    grand_total = 0

    active_articles.each do |article|
      lines = lines_by_article_and_variant[[article.id, nil]] || []
      total_quantity = lines.sum { |l| l.quantity.to_i }
      cost = article.cost || 0
      total_value = total_quantity * cost

      total_cost += cost
      grand_total += total_value

      table_data << [
        article.name,
        total_quantity.to_s,
        helpers.number_to_currency(cost, unit: ''),
        helpers.number_to_currency(total_value, unit: '')
      ]

      article.variants.each do |variant|
        v_lines = lines_by_article_and_variant[[article.id, variant.id]] || []
        v_quantity = v_lines.sum { |l| l.quantity.to_i }
        v_cost = variant.cost.presence || article.cost || 0
        v_total_value = v_quantity * v_cost

        total_cost += v_cost
        grand_total += v_total_value

        table_data << [
          "  -> #{variant.name}",
          v_quantity.to_s,
          helpers.number_to_currency(v_cost, unit: ''),
          helpers.number_to_currency(v_total_value, unit: '')
        ]
      end
    end

    table_data << [
      "Total",
      "",
      "",
      helpers.number_to_currency(grand_total, unit: '')
    ]

    pdf.fill_color "1A1A1A"
    pdf.table(
      table_data,
      header: true,
      width: pdf.bounds.width,
      row_colors: ["FFFFFF", "FFFBEB"],
      cell_style: {
        font: "Courier",
        size: 10,
        border_color: "2C2C2C",
        border_width: 1.5,
        padding: [7, 8, 7, 8],
        text_color: "1A1A1A"
      }
    ) do
      row(0).font_style = :bold
      row(0).background_color = "2C2C2C"
      row(0).text_color = "FFD100"
      row(0).border_bottom_width = 3
      row(0).border_bottom_color = "FFD100"

      column(1).align = :right
      column(2).align = :right
      column(3).align = :right

      row(-1).font_style = :bold
      row(-1).background_color = "FFD100"
      row(-1).text_color = "1A1A1A"
      row(-1).border_top_width = 2.5
      row(-1).border_bottom_width = 2.5
    end

    pdf.move_down 16
    pdf.fill_color "2C2C2C"
    pdf.text "=== [ HIGH SCORE SUMMARY // END OF REPORT ] ===", size: 9, align: :center, style: :bold

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
        format.html { redirect_to @inventory, notice: "Inventar wurde erfolgreich erstellt." }
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
        format.html { redirect_to @inventory, notice: "Inventar wurde erfolgreich aktualisiert.", status: :see_other }
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
      format.html { redirect_to inventories_path, notice: "Inventar wurde erfolgreich gelöscht.", status: :see_other }
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
