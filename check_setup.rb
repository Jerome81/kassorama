
puts "--- Tax Codes ---"
TaxCode.all.each { |t| puts "#{t.name}: #{t.rate}" }
puts "--- Tip Article ---"
a = Article.find_by(barcode: 'tip')
if a
  puts "Article 'tip' exists. ID: #{a.id}"
else
  puts "Article 'tip' MISSING."
end
