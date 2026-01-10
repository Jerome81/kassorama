require "test_helper"

class SectionsControllerTest < ActionDispatch::IntegrationTest
  test "should get edit" do
    get sections_edit_url
    assert_response :success
  end

  test "should get update" do
    get sections_update_url
    assert_response :success
  end
end
