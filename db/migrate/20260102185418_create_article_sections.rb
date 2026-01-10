class CreateArticleSections < ActiveRecord::Migration[7.1]
  def change
    create_table :article_sections do |t|
      t.references :article, null: false, foreign_key: true
      t.references :section, null: false, foreign_key: true

      t.timestamps
    end
  end
end
