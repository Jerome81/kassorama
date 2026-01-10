require "application_system_test_case"

class TaxCodesTest < ApplicationSystemTestCase
  setup do
    @tax_code = tax_codes(:one)
  end

  test "visiting the index" do
    visit tax_codes_url
    assert_selector "h1", text: "Tax codes"
  end

  test "should create tax code" do
    visit tax_codes_url
    click_on "New tax code"

    fill_in "Rate", with: @tax_code.rate
    click_on "Create Tax code"

    assert_text "Tax code was successfully created"
    click_on "Back"
  end

  test "should update Tax code" do
    visit tax_code_url(@tax_code)
    click_on "Edit this tax code", match: :first

    fill_in "Rate", with: @tax_code.rate
    click_on "Update Tax code"

    assert_text "Tax code was successfully updated"
    click_on "Back"
  end

  test "should destroy Tax code" do
    visit tax_code_url(@tax_code)
    accept_confirm { click_on "Destroy this tax code", match: :first }

    assert_text "Tax code was successfully destroyed"
  end
end
