class AddArticleCategoryToArticles < ActiveRecord::Migration[7.1]
  def change
    add_reference :articles, :article_category, null: true, foreign_key: true
  end
end
