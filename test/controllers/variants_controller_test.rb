require "test_helper"

class VariantsControllerTest < ActionDispatch::IntegrationTest
  test "should get edit" do
    get variants_edit_url
    assert_response :success
  end

  test "should get update" do
    get variants_update_url
    assert_response :success
  end
end
