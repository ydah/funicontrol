require "test_helper"

class FunicontrolApiTest < ActionDispatch::IntegrationTest
  include ActionCable::TestHelper

  test "line endpoints return the seeded control data shape" do
    line = create_funicontrol_line

    get "/api/lines"
    assert_response :success
    assert_equal line.id, response.parsed_body.last["id"]

    get "/api/lines/#{line.id}"
    assert_response :success
    body = response.parsed_body
    assert_equal 3, body["stations"].length
    assert_equal 2, body["cars"].length

    get "/api/lines/#{line.id}/stations"
    assert_response :success
    assert_equal 3, response.parsed_body.length

    get "/api/lines/#{line.id}/cars"
    assert_response :success
    assert_equal 2, response.parsed_body.length
  end

  test "dispatch endpoint updates car and returns car plus event" do
    car = create_funicontrol_line.cars.first

    post "/api/cars/#{car.id}/dispatch", params: { action: "emergency_stop", reason: "test" }, as: :json

    assert_response :success
    assert_equal "emergency", response.parsed_body["car"]["status"]
    assert_equal "car_emergency_stopped", response.parsed_body["event"]["event_type"]
  end

  test "line-scoped dispatch uses stable car code instead of stale client car id" do
    line = create_funicontrol_line
    car = line.cars.find_by!(code: "car_a")

    post "/api/lines/#{line.id}/dispatch",
      params: { action: "start", car_id: 45, code: "car_a", reason: "line scoped" },
      as: :json

    assert_response :success
    assert_equal car.id, response.parsed_body["car"]["id"]
    assert_equal "car_started", response.parsed_body["event"]["event_type"]
  end

  test "dispatch endpoint recovers from stale client car id when line context is available" do
    line = create_funicontrol_line
    car = line.cars.second

    post "/api/cars/999999/dispatch",
      params: { action: "stop", line_id: line.id, code: car.code },
      as: :json

    assert_response :success
    assert_equal car.id, response.parsed_body["car"]["id"]
    assert_equal "stopped", response.parsed_body["car"]["status"]
  end

  test "dispatch endpoint recovers from stale client car id using line referer" do
    line = create_funicontrol_line

    post "/api/cars/999999/dispatch",
      params: { action: "slow" },
      headers: { "HTTP_REFERER" => "http://www.example.com/lines/#{line.id}" },
      as: :json

    assert_response :success
    assert_equal line.cars.order(:code).first.id, response.parsed_body["car"]["id"]
    assert_equal "slow", response.parsed_body["car"]["status"]
  end

  test "dispatch endpoint prefers current line referer over stale payload line id" do
    current_line = create_funicontrol_line
    stale_line = create_funicontrol_line
    car = current_line.cars.find_by!(code: "car_a")

    post "/api/cars/45/dispatch",
      params: { action: "start", line_id: stale_line.id, code: car.code },
      headers: { "HTTP_REFERER" => "http://www.example.com/lines/#{current_line.id}" },
      as: :json

    assert_response :success
    assert_equal car.id, response.parsed_body["car"]["id"]
    assert_equal current_line.id, response.parsed_body["car"]["line_id"]
  end

  test "dispatch endpoint falls back to the available line when stale payload has no referer" do
    line = create_funicontrol_line

    post "/api/cars/45/dispatch",
      params: { action: "start", line_id: 57, code: "car_a" },
      as: :json

    assert_response :success
    assert_equal line.cars.find_by!(code: "car_a").id, response.parsed_body["car"]["id"]
  end

  test "line suspend and resume endpoints update status and record events" do
    line = create_funicontrol_line

    assert_broadcasts("line_#{line.id}", 1) do
      post "/api/lines/#{line.id}/suspend", params: { reason: "wind" }, as: :json
    end
    assert_response :success
    assert_equal "suspended", response.parsed_body["line"]["status"]
    assert_equal "line_suspended", response.parsed_body["event"]["event_type"]
    assert_equal "wind", response.parsed_body["event"]["payload"]["reason"]

    assert_broadcasts("line_#{line.id}", 1) do
      post "/api/lines/#{line.id}/resume", params: { reason: "clear" }, as: :json
    end
    assert_response :success
    assert_equal "normal", response.parsed_body["line"]["status"]
    assert_equal "line_resumed", response.parsed_body["event"]["event_type"]
  end

  test "station alert endpoints update station and record events" do
    line = create_funicontrol_line
    station = line.stations.second

    assert_broadcasts("line_#{line.id}", 1) do
      post "/api/lines/#{line.id}/stations/#{station.id}/raise_alert",
        params: { reason: "crowding" },
        as: :json
    end
    assert_response :success
    assert_equal "alert", response.parsed_body["station"]["status"]
    assert_equal "station_alert_raised", response.parsed_body["event"]["event_type"]
    assert_equal station.id, response.parsed_body["event"]["station_id"]

    assert_broadcasts("line_#{line.id}", 1) do
      post "/api/lines/#{line.id}/stations/#{station.id}/clear_alert",
        params: { reason: "handled" },
        as: :json
    end
    assert_response :success
    assert_equal "normal", response.parsed_body["station"]["status"]
    assert_equal "station_alert_cleared", response.parsed_body["event"]["event_type"]
  end

  test "incident lifecycle and comments work through json api" do
    line = create_funicontrol_line

    post "/api/lines/#{line.id}/incidents",
      params: { kind: "inspection", severity: "high", title: "Track noise", description: "near middle" },
      as: :json
    assert_response :created
    incident_id = response.parsed_body["id"]

    get "/api/lines/#{line.id}/incidents"
    assert_response :success
    assert_equal incident_id, response.parsed_body.first["id"]

    get "/api/incidents/#{incident_id}"
    assert_response :success
    assert_equal "Track noise", response.parsed_body["title"]

    patch "/api/incidents/#{incident_id}", params: { status: "acknowledged" }, as: :json
    assert_response :success
    assert_equal "acknowledged", response.parsed_body["status"]

    post "/api/incidents/#{incident_id}/incident_comments",
      params: { author_name: "operator", body: "Crew notified" },
      as: :json
    assert_response :created
    assert_equal "Crew notified", response.parsed_body["body"]

    get "/api/incidents/#{incident_id}/incident_comments"
    assert_response :success
    assert_equal 1, response.parsed_body.length

    post "/api/incidents/#{incident_id}/resolve"
    assert_response :success
    assert_equal "resolved", response.parsed_body["status"]
  end

  test "incident can include an uploaded photo" do
    line = create_funicontrol_line
    photo = fixture_file_upload("incident_photo.txt", "text/plain")

    post "/api/lines/#{line.id}/incidents",
      params: {
        kind: "inspection",
        severity: "low",
        title: "Photo report",
        description: "attached",
        photo: photo
      }

    assert_response :created
    body = response.parsed_body
    assert_equal "incident_photo.txt", body["photo_filename"]
    assert body["photo_url"].present?
    assert Incident.find(body["id"]).photo.attached?
  end

  test "operation events support line log query and schemas are available" do
    line = create_funicontrol_line
    older_event = line.operation_events.create!(event_type: "line_suspended", occurred_at: 1.minute.ago)
    newer_event = line.operation_events.create!(event_type: "line_resumed", occurred_at: Time.current)

    get "/api/lines/#{line.id}/operation_events?limit=1"
    assert_response :success
    assert_equal 1, response.parsed_body.length
    assert_equal newer_event.id, response.parsed_body.first["id"]

    get "/api/lines/#{line.id}/operation_events?after_id=#{older_event.id}"
    assert_response :success
    assert_equal [ newer_event.id ], response.parsed_body.map { |event| event["id"] }

    get "/api/lines/#{line.id}"
    assert_response :success
    assert_nil response.parsed_body["recent_events"]

    get "/api/schema/line"
    assert_response :success
    assert_includes response.parsed_body["attributes"].keys, "name"
  end

  test "validation errors use the unified errors object" do
    line = create_funicontrol_line

    post "/api/lines/#{line.id}/incidents", params: { kind: "other" }, as: :json

    assert_response :unprocessable_entity
    assert response.parsed_body["errors"]["title"].present?
  end
end
