class CreateTaxCodes < ActiveRecord::Migration[7.1]
  def change
    create_table :tax_codes do |t|
      t.decimal :rate

      t.timestamps
    end
  end
end
