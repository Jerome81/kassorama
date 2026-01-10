require "test_helper"

class StockOrdersControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get stock_orders_index_url
    assert_response :success
  end
end
