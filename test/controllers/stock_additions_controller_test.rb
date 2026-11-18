require "test_helper"

class StockAdditionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    post login_url, params: { user_id: @user.id, pin: @user.pin }
    @location_one = Location.create!(name: "Shop")
    @location_two = Location.create!(name: "Lager")
    @tax_code = TaxCode.first || TaxCode.create!(code: "STD", rate: 8.1)
    @article = Article.create!(
      name: "Test Artikel",
      sku: "SKU-1001",
      barcode: "4001001",
      price: 15.0,
      price_type: "fixed",
      status: "active",
      tax_code: @tax_code
    )
  end

  test "should get index" do
    get stock_additions_url
    assert_response :success
  end

  test "should auto-add article on barcode scan and add quantities to locations" do
    get stock_additions_url, params: { search_query: "4001001" }
    assert_response :success
    assert_includes session[:stock_addition_article_ids], @article.id

    post stock_additions_url, params: {
      quantities: {
        @article.id.to_s => {
          @location_one.id.to_s => "5",
          @location_two.id.to_s => "12"
        }
      }
    }

    assert_redirected_to stock_additions_url
    assert_equal 5, Stock.find_by(article: @article, location: @location_one, variant: nil)&.quantity
    assert_equal 12, Stock.find_by(article: @article, location: @location_two, variant: nil)&.quantity
    assert_empty session[:stock_addition_article_ids]
  end
end
