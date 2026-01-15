
tax = TaxCode.find_by(rate: 0.0) || TaxCode.first
if tax
  tip = Article.find_or_initialize_by(barcode: 'tip')
  tip.sku = 'TIP-001' if tip.new_record?
  tip.name = 'Trinkgeld'
  tip.price_type = 'free'
  tip.price = 0.0
  tip.tax_code = tax
  if tip.save
    puts "Tip article ready: #{tip.id}"
  else
    puts "Error saving tip article: #{tip.errors.full_messages}"
  end
else
  puts "No tax code found!"
end
