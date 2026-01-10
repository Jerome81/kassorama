# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

puts "Seeding data..."

# Create Tax Codes
tax_low = TaxCode.find_or_create_by!(rate: 2.6)
tax_high = TaxCode.find_or_create_by!(rate: 8.1)

warehouse = Location.find_or_create_by!(name: "Warehouse")
showroom = Location.find_or_create_by!(name: "Showroom")

register = CashRegister.find_or_create_by!(name: "Main Register", status: "active")

# Create Sections for the register
Section.find_or_create_by!(name: "Clothes", group_filter: "Apparel", cash_register: register)
Section.find_or_create_by!(name: "General", group_filter: "General", cash_register: register)

if Article.count == 0
  tshirt = Article.create!(
    name: "Classic T-Shirt",
    sku: "TSHIRT001",
    barcode: "12345678",
    price: 19.90,
    # mwst: 8.1, (Removed)
    tax_code: tax_high,
    group: "Apparel",
    picture: "https://placehold.co/400x400?text=T-Shirt",
    status: "active"
  )
  
  jeans = Article.create!(
    name: "Blue Jeans",
    sku: "JEANS001",
    barcode: "87654321",
    price: 49.50,
    tax_code: tax_high,
    group: "Apparel",
    picture: "https://placehold.co/400x400?text=Jeans",
    status: "active"
  )

  # Stock
  Stock.create!(article: tshirt, location: showroom, quantity: 10)
  Stock.create!(article: tshirt, location: warehouse, quantity: 50)
  Stock.create!(article: jeans, location: showroom, quantity: 5)
  Stock.create!(article: jeans, location: warehouse, quantity: 20)
  
  puts "Created Articles and Stock."
else
  puts "Articles already exist."
end

User.find_or_create_by!(name: "Admin") do |u|
  u.role = "Admin"
  u.pin = "223322"
end

puts "Seeding done."
