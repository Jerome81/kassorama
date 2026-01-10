require "test_helper"

class PosControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get pos_index_url
    assert_response :success
  end

  test "should get show" do
    get pos_show_url
    assert_response :success
  end

  test "should get add_item" do
    get pos_add_item_url
    assert_response :success
  end

  test "should get checkout" do
    get pos_checkout_url
    assert_response :success
  end
end
