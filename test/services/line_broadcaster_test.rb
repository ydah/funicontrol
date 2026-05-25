require "test_helper"

class LineBroadcasterTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  test "payload builder exposes sequence and serialized event" do
    line = create_funicontrol_line
    car = line.cars.first
    event = RecordOperationEvent.call(line:, car:, event_type: "car_stopped", payload: {action: "stop"})

    payload = LineBroadcastPayload.operation_event(car:, event:)

    assert_equal "operation_event", payload[:type]
    assert_equal "car_stopped", payload[:event_type]
    assert_equal event.id, payload[:sequence]
    assert_equal car.id, payload[:car][:id]
  end

  test "broadcast failures are logged without raising" do
    line = create_funicontrol_line
    car = line.cars.first
    event = RecordOperationEvent.call(line:, car:, event_type: "car_stopped", payload: {action: "stop"})

    server = ActionCable.server
    original_broadcast = server.method(:broadcast)
    server.define_singleton_method(:broadcast) { |*| raise "broadcast down" }
    begin
      assert_nothing_raised do
        LineBroadcaster.broadcast_operation_event(line:, car:, event:)
      end
    ensure
      server.define_singleton_method(:broadcast) { |*args| original_broadcast.call(*args) }
    end
  end
end
