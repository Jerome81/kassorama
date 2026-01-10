class ArticleSection < ApplicationRecord
  belongs_to :article
  belongs_to :section
end
