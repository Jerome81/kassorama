require "test_helper"

class ArticleStatsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get article_stats_index_url
    assert_response :success
  end
end
