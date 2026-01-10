class CreateSections < ActiveRecord::Migration[7.1]
  def change
    create_table :sections do |t|
      t.string :name
      t.string :group_filter
      t.references :cash_register, null: false, foreign_key: true

      t.timestamps
    end
  end
end
