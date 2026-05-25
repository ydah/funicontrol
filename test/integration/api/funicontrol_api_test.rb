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
    assert_includes body.keys, "track_segments"

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

  test "dispatch endpoint does not infer a stale or missing car target" do
    line = create_funicontrol_line

    post "/api/cars/999999/dispatch",
      params: { action: "stop", line_id: line.id, code: "car_a" },
      as: :json
    assert_response :not_found

    post "/api/lines/#{line.id}/dispatch",
      params: { action: "start" },
      as: :json
    assert_response :bad_request
    assert response.parsed_body["errors"]["base"].first.include?("car_id or code")
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

    assert_broadcasts("line_#{line.id}", 1) do
      post "/api/lines/#{line.id}/enter_maintenance", params: { reason: "inspection" }, as: :json
    end
    assert_response :success
    assert_equal "maintenance", response.parsed_body["line"]["status"]

    assert_broadcasts("line_#{line.id}", 1) do
      post "/api/lines/#{line.id}/exit_maintenance", params: { reason: "done" }, as: :json
    end
    assert_response :success
    assert_equal "normal", response.parsed_body["line"]["status"]
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

    post "/api/lines/#{line.id}/stations/#{station.id}/mark_crowded",
      params: { reason: "platform" },
      as: :json
    assert_response :success
    assert_equal "crowded", response.parsed_body["station"]["status"]

    post "/api/lines/#{line.id}/stations/#{station.id}/close",
      params: { reason: "inspection" },
      as: :json
    assert_response :success
    assert_equal "closed", response.parsed_body["station"]["status"]

    post "/api/lines/#{line.id}/stations/#{station.id}/reopen",
      params: { reason: "clear" },
      as: :json
    assert_response :success
    assert_equal "normal", response.parsed_body["station"]["status"]
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

    post "/api/incidents/#{incident_id}/acknowledge"
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
    incident = Incident.find(body["id"])
    assert incident.attachments.attached?
    assert_equal "incident_photo.txt", incident.attachments.first.filename.to_s
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

    get "/api/lines/#{line.id}/operation_events?order=asc"
    assert_response :success
    assert_equal [ older_event.id, newer_event.id ], response.parsed_body.map { |event| event["id"] }.last(2)

    get "/api/lines/#{line.id}/operation_events?since=not-a-time"
    assert_response :bad_request

    get "/api/lines/#{line.id}"
    assert_response :success
    assert_nil response.parsed_body["recent_events"]

    get "/api/schema/line"
    assert_response :success
    assert_includes response.parsed_body["attributes"].keys, "name"
  end

  test "weather reports and scenario import endpoints work" do
    line = create_funicontrol_line

    post "/api/lines/#{line.id}/weather", params: { weather_condition: "fog", reason: "visibility" }, as: :json
    assert_response :success
    assert_equal "fog", response.parsed_body["line"]["weather_condition"]
    assert_equal "line_weather_changed", response.parsed_body["event"]["event_type"]

    get "/api/reports/daily", params: { line_id: line.id, date: Date.current.iso8601 }
    assert_response :success
    assert_equal line.id, response.parsed_body["line_id"]
    assert response.parsed_body["payload"]["event_counts"].present?

    post "/api/scenarios/import",
      params: {
        line_id: line.id,
        events: [
          {
            event_type: "operator_message_sent",
            payload: { message: "Replay note" },
            occurred_at: Time.current.iso8601
          }
        ]
      },
      as: :json
    assert_response :created
    assert_equal 1, response.parsed_body["imported_count"]
  end

  test "validation errors use the unified errors object" do
    line = create_funicontrol_line

    post "/api/lines/#{line.id}/incidents", params: { kind: "other" }, as: :json

    assert_response :unprocessable_entity
    assert response.parsed_body["errors"]["title"].present?
  end
end
