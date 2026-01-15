# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_01_15_212859) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "article_categories", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "article_sections", force: :cascade do |t|
    t.integer "article_id", null: false
    t.integer "section_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "sort_order"
    t.index ["article_id"], name: "index_article_sections_on_article_id"
    t.index ["section_id"], name: "index_article_sections_on_section_id"
  end

  create_table "articles", force: :cascade do |t|
    t.string "name"
    t.string "sku"
    t.string "barcode"
    t.decimal "price", precision: 10, scale: 2
    t.string "picture"
    t.string "status"
    t.integer "sales_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "tax_code_id"
    t.decimal "cost", precision: 10, scale: 2
    t.string "price_type", default: "fixed"
    t.boolean "is_voucher", default: false
    t.integer "article_category_id"
    t.integer "supplier_id"
    t.string "booking_account"
    t.index ["article_category_id"], name: "index_articles_on_article_category_id"
    t.index ["barcode"], name: "index_articles_on_barcode"
    t.index ["sku"], name: "index_articles_on_sku", unique: true
    t.index ["supplier_id"], name: "index_articles_on_supplier_id"
    t.index ["tax_code_id"], name: "index_articles_on_tax_code_id"
  end

  create_table "bexio_accounts", force: :cascade do |t|
    t.string "bexio_id"
    t.string "account_number"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "bexio_tax_codes", force: :cascade do |t|
    t.string "bexio_id"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "cash_registers", force: :cascade do |t|
    t.string "name"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "stock_location_id"
    t.decimal "amount", precision: 10, scale: 2, default: "0.0"
    t.string "precreated_tabs"
    t.index ["stock_location_id"], name: "index_cash_registers_on_stock_location_id"
  end

  create_table "entries", force: :cascade do |t|
    t.date "booking_date"
    t.string "debit_account"
    t.string "credit_account"
    t.string "description"
    t.string "tax_code"
    t.decimal "amount"
    t.string "reference_number"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "exported_at"
  end

  create_table "inventories", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "completed_at"
  end

  create_table "inventory_lines", force: :cascade do |t|
    t.integer "inventory_id", null: false
    t.integer "article_id", null: false
    t.integer "location_id", null: false
    t.integer "quantity"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "diff"
    t.integer "variant_id"
    t.index ["article_id"], name: "index_inventory_lines_on_article_id"
    t.index ["inventory_id"], name: "index_inventory_lines_on_inventory_id"
    t.index ["location_id"], name: "index_inventory_lines_on_location_id"
    t.index ["variant_id"], name: "index_inventory_lines_on_variant_id"
  end

  create_table "locations", force: :cascade do |t|
    t.string "name"
    t.string "address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "order_items", force: :cascade do |t|
    t.integer "order_id", null: false
    t.integer "article_id", null: false
    t.integer "quantity"
    t.decimal "unit_price", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "gross_price", precision: 10, scale: 2
    t.decimal "discount", precision: 10, scale: 2
    t.decimal "net_price", precision: 10, scale: 2
    t.integer "variant_id"
    t.index ["article_id"], name: "index_order_items_on_article_id"
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["variant_id"], name: "index_order_items_on_variant_id"
  end

  create_table "orders", force: :cascade do |t|
    t.integer "cash_register_id", null: false
    t.decimal "total_amount", precision: 10, scale: 2
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "discount", precision: 10, scale: 2
    t.string "voucher"
    t.string "payment_method"
    t.string "name"
    t.datetime "exported"
    t.string "user_name"
    t.index ["cash_register_id"], name: "index_orders_on_cash_register_id"
  end

  create_table "revolut_transactions", force: :cascade do |t|
    t.date "date"
    t.string "state"
    t.string "description"
    t.string "payer"
    t.decimal "original_amount"
    t.string "original_currency"
    t.decimal "total_amount"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "exported"
    t.string "debit_account"
    t.string "credit_account"
    t.string "tax_code"
  end

  create_table "sections", force: :cascade do |t|
    t.string "name"
    t.integer "cash_register_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cash_register_id"], name: "index_sections_on_cash_register_id"
  end

  create_table "settings", force: :cascade do |t|
    t.string "key"
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_settings_on_key"
  end

  create_table "stocks", force: :cascade do |t|
    t.integer "article_id", null: false
    t.integer "location_id", null: false
    t.integer "quantity"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "variant_id"
    t.index ["article_id"], name: "index_stocks_on_article_id"
    t.index ["location_id"], name: "index_stocks_on_location_id"
    t.index ["variant_id"], name: "index_stocks_on_variant_id"
  end

  create_table "suppliers", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tax_codes", force: :cascade do |t|
    t.decimal "rate"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "transactions", force: :cascade do |t|
    t.string "transaction_type"
    t.decimal "amount", precision: 10, scale: 2
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "exported"
    t.string "user_name"
    t.integer "cash_register_id"
    t.index ["cash_register_id"], name: "index_transactions_on_cash_register_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "pin"
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "variants", force: :cascade do |t|
    t.integer "article_id", null: false
    t.string "name"
    t.string "barcode"
    t.decimal "price", precision: 10, scale: 2
    t.string "picture"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "sku"
    t.index ["article_id"], name: "index_variants_on_article_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "article_sections", "articles"
  add_foreign_key "article_sections", "sections"
  add_foreign_key "articles", "article_categories"
  add_foreign_key "articles", "suppliers"
  add_foreign_key "articles", "tax_codes"
  add_foreign_key "cash_registers", "locations", column: "stock_location_id"
  add_foreign_key "inventory_lines", "articles"
  add_foreign_key "inventory_lines", "inventories"
  add_foreign_key "inventory_lines", "locations"
  add_foreign_key "inventory_lines", "variants"
  add_foreign_key "order_items", "articles"
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "variants"
  add_foreign_key "orders", "cash_registers"
  add_foreign_key "sections", "cash_registers"
  add_foreign_key "stocks", "articles"
  add_foreign_key "stocks", "locations"
  add_foreign_key "stocks", "variants"
  add_foreign_key "transactions", "cash_registers"
  add_foreign_key "variants", "articles"
end
