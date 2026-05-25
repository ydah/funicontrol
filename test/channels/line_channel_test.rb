require "test_helper"

class LineChannelTest < ActionCable::Channel::TestCase
  test "subscribes to a line stream" do
    line = create_funicontrol_line

    subscribe line_id: line.id

    assert subscription.confirmed?
    assert_has_stream "line_#{line.id}"
  end

  test "dispatch updates a car and broadcasts operation event" do
    line = create_funicontrol_line
    car = line.cars.first
    subscribe line_id: line.id

    assert_broadcasts("line_#{line.id}", 1) do
      perform :dispatch, car_id: car.id, command: "stop", reason: "channel test"
    end

    assert_equal "stopped", car.reload.status
    assert_equal "car_stopped", line.operation_events.order(:id).last.event_type
  end

  test "dispatch recovers from stale car id inside the subscribed line" do
    line = create_funicontrol_line
    subscribe line_id: line.id

    assert_broadcasts("line_#{line.id}", 1) do
      perform :dispatch, car_id: 45, command: "start", reason: "stale channel id"
    end

    event = line.operation_events.order(:id).last
    assert_equal "car_started", event.event_type
    assert_equal line.cars.order(:code).first.id, event.car_id
  end
end
