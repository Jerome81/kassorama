
# Script to verify OrderItem merging logic
order = Order.create!(cash_register: CashRegister.first, status: 'pending')
article = Article.create!(name: "Test Shirt", price: 10, tax_code: TaxCode.first, supplier: Supplier.first, article_category: ArticleCategory.first)
v1 = Variant.create!(article: article, name: "Red", price: 10, barcode: "RED123")
v2 = Variant.create!(article: article, name: "Blue", price: 10, barcode: "BLUE123")

puts "Adding Red..."
item1 = order.order_items.find_or_initialize_by(article: article, variant: v1)
item1.quantity = (item1.quantity || 0) + 1
item1.unit_price = v1.price
item1.save!
puts "Item1: #{item1.id} | Variant: #{item1.variant&.name} | Qty: #{item1.quantity}"

puts "Adding Blue..."
item2 = order.order_items.find_or_initialize_by(article: article, variant: v2)
item2.quantity = (item2.quantity || 0) + 1
item2.unit_price = v2.price
item2.save!
puts "Item2: #{item2.id} | Variant: #{item2.variant&.name} | Qty: #{item2.quantity}"

if item1.id == item2.id
  puts "ERROR: Items merged!"
else
  puts "SUCCESS: Items distinct."
end
