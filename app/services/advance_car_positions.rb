class AdvanceCarPositions
  def self.call(line:)
    new(line:).call
  end

  def initialize(line:)
    @line = line
  end

  def call
    Car.where(line_id: line.id).find_each do |car|
      car.reload
      next unless car.status.in?(%w[running slow])

      update_car_position(car)
    end
  end

  private

  attr_reader :line

  def update_car_position(car)
    next_position = car.position.to_f + position_delta(car)
    next_direction = car.direction

    if next_position >= 1.0
      next_position = 1.0
      next_direction = "down"
    elsif next_position <= 0.0
      next_position = 0.0
      next_direction = "up"
    end

    car.update!(
      position: next_position,
      direction: next_direction,
      last_seen_at: Time.current
    )

    event = OperationEvent.create!(
      line: car.line,
      car:,
      event_type: "car_position_updated",
      payload: {
        position: car.position.to_f,
        direction: car.direction,
        speed: car.speed.to_f,
        status: car.status
      },
      occurred_at: Time.current
    )

    LineBroadcaster.broadcast_car_position_updated(line: car.line, car:, event:)
  end

  def position_delta(car)
    car.direction == "down" ? -car.speed.to_f : car.speed.to_f
  end
end
