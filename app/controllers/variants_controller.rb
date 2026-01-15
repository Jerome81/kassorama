class VariantsController < ApplicationController
  before_action :set_variant, only: %i[ edit update ]

  def edit
  end

  def update
    if @variant.update(variant_params)
      redirect_to article_path(@variant.article), notice: "Variant updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_variant
      @variant = Variant.find(params[:id])
    end

    def variant_params
      params.require(:variant).permit(:name, :price, :barcode, :sku)
    end
end
