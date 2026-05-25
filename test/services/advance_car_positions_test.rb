require "test_helper"

class AdvanceCarPositionsTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  test "running cars move and broadcast position updates" do
    line = create_funicontrol_line
    car = line.cars.first

    assert_difference "OperationEvent.count", 2 do
      assert_broadcasts("line_#{line.id}", 1) do
        AdvanceCarPositions.call(line:)
      end
    end

    assert_operator car.reload.position, :>, 0.2
  end

  test "stopped cars do not move" do
    line = create_funicontrol_line
    car = line.cars.first
    car.update!(status: "stopped", speed: 0, direction: "idle")

    assert_no_changes -> { car.reload.position } do
      AdvanceCarPositions.call(line:)
    end
  end

  test "cars dwell at route edges before reversing direction" do
    line = create_funicontrol_line
    car = line.cars.first
    car.update!(position: 0.99, direction: "up", speed: 0.02, status: "running")

    AdvanceCarPositions.call(line:)

    assert_equal 1.0, car.reload.position.to_f
    assert_equal "idle", car.direction
    assert_equal "stopped", car.status
    assert car.dwell_until.present?
  end
end
