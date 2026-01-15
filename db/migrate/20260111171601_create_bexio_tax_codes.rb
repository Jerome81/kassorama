class CreateBexioTaxCodes < ActiveRecord::Migration[7.1]
  def change
    create_table :bexio_tax_codes do |t|
      t.string :bexio_id
      t.string :name

      t.timestamps
    end
  end
end
