require "test_helper"

class FunicontrolSpaTest < ActionDispatch::IntegrationTest
  test "spa shell serves funicular runtime and integration assets" do
    get "/dashboard"

    assert_response :success
    assert_includes response.body, "application/x-mrb"
    assert_includes response.body, "line_map_renderer"
    assert_includes response.body, "funicontrol_upload"
    assert_includes response.body, "funicontrol-root"
  end

  test "client routes fall back to the spa shell" do
    line = create_funicontrol_line

    get "/lines/#{line.id}"
    assert_response :success
    assert_includes response.body, "funicontrol-root"

    get "/cars/#{line.cars.first.id}"
    assert_response :success
    assert_includes response.body, "funicontrol-root"
  end
end
