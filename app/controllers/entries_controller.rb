class EntriesController < ApplicationController
  def index
    @entries = Entry.where(exported_at: nil).order(booking_date: :desc, created_at: :desc)
  end
  def update
    @entry = Entry.find(params[:id])
    if @entry.update(entry_params)
      head :ok
    else
      render json: { errors: @entry.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def entry_params
    params.require(:entry).permit(:booking_date, :debit_account, :credit_account, :description, :tax_code, :amount, :reference_number)
  end
end
