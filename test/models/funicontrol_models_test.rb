require "test_helper"

class FunicontrolModelsTest < ActiveSupport::TestCase
  test "line has stations cars incidents and operation events" do
    line = create_funicontrol_line
    incident = line.incidents.create!(kind: "inspection", severity: "medium", status: "open", title: "Noise")
    event = line.operation_events.create!(event_type: "incident_created", incident:, occurred_at: Time.current)

    assert_equal 3, line.stations.count
    assert_equal 2, line.cars.count
    assert_equal [ incident ], line.incidents.to_a
    assert_equal [ event ], line.operation_events.to_a
  end

  test "station and car positions must be between zero and one" do
    line = create_funicontrol_line

    station = line.stations.build(name: "Invalid", position: 1.5, status: "normal", passenger_level: 10)
    car = line.cars.build(name: "Invalid", code: "invalid", position: -0.1, direction: "up", speed: 0.01, status: "running")

    assert_not station.valid?
    assert_not car.valid?
  end

  test "statuses and incident fields are validated" do
    line = create_funicontrol_line

    car = line.cars.build(name: "Bad", code: "bad", position: 0.2, direction: "sideways", speed: 0.1, status: "flying")
    incident = line.incidents.build(kind: "mystery", severity: "urgent", status: "new", title: "")
    comment = IncidentComment.new(incident:, author_name: "", body: "")
    event = line.operation_events.build(event_type: "unknown", occurred_at: nil)

    assert_not car.valid?
    assert_not incident.valid?
    assert_not comment.valid?
    assert_not event.valid?
  end
end
