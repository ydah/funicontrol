require "test_helper"

class DispatchCarTest < ActiveSupport::TestCase
  test "start sets running and records an event" do
    car = create_funicontrol_line.cars.first
    car.update!(status: "stopped", speed: 0, direction: "idle")

    result = nil
    assert_difference "OperationEvent.count", 1 do
      result = DispatchCar.call(car:, action: "start", reason: "ready")
    end

    assert_equal "running", result.car.status
    assert_equal "car_started", result.event.event_type
    assert_equal "ready", result.event.payload["reason"]
  end

  test "stop slow emergency_stop and recover update status" do
    car = create_funicontrol_line.cars.first

    assert_equal "slow", DispatchCar.call(car:, action: "slow").car.status
    assert_equal "emergency", DispatchCar.call(car:, action: "emergency_stop").car.status
    assert_equal "stopped", DispatchCar.call(car:, action: "recover").car.status
    assert_equal "stopped", DispatchCar.call(car:, action: "stop").car.status
  end

  test "unknown action raises argument error" do
    car = create_funicontrol_line.cars.first

    assert_raises(ArgumentError) do
      DispatchCar.call(car:, action: "launch")
    end
  end
end
