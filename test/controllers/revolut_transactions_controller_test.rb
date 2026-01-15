require "test_helper"

class RevolutTransactionsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get revolut_transactions_index_url
    assert_response :success
  end
end
