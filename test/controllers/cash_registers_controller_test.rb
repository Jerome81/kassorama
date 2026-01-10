require "test_helper"

class CashRegistersControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get cash_registers_index_url
    assert_response :success
  end

  test "should get show" do
    get cash_registers_show_url
    assert_response :success
  end

  test "should get new" do
    get cash_registers_new_url
    assert_response :success
  end

  test "should get create" do
    get cash_registers_create_url
    assert_response :success
  end

  test "should get edit" do
    get cash_registers_edit_url
    assert_response :success
  end

  test "should get update" do
    get cash_registers_update_url
    assert_response :success
  end

  test "should get destroy" do
    get cash_registers_destroy_url
    assert_response :success
  end
end
