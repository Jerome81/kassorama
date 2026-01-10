require "test_helper"

class StockTransfersControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get stock_transfers_index_url
    assert_response :success
  end
end
