class DispatchCar
  Result = Data.define(:car, :event)

  ACTION_EVENT_TYPES = {
    "start" => "car_started",
    "stop" => "car_stopped",
    "slow" => "car_slowed",
    "emergency_stop" => "car_emergency_stopped",
    "recover" => "car_recovered"
  }.freeze

  def self.call(car:, action:, reason: nil)
    new(car:, action:, reason:).call
  end

  def initialize(car:, action:, reason: nil)
    @car = car
    @action = action.to_s
    @reason = reason
  end

  def call
    ActiveRecord::Base.transaction do
      apply_action!
      event = record_event!
      Result.new(car: @car, event:)
    end
  end

  private

  attr_reader :car, :action, :reason

  def apply_action!
    raise ArgumentError, "Unknown dispatch action: #{action}" unless ACTION_EVENT_TYPES.key?(action)

    case action
    when "start"
      car.update!(status: "running", speed: 0.02, direction: inferred_direction, last_seen_at: Time.current)
    when "stop"
      car.update!(status: "stopped", speed: 0.0, direction: "idle", last_seen_at: Time.current)
    when "slow"
      car.update!(status: "slow", speed: 0.008, direction: car.direction == "idle" ? inferred_direction : car.direction, last_seen_at: Time.current)
    when "emergency_stop"
      car.update!(status: "emergency", speed: 0.0, direction: "idle", last_seen_at: Time.current)
    when "recover"
      car.update!(status: "stopped", speed: 0.0, direction: "idle", last_seen_at: Time.current)
    end
  end

  def record_event!
    OperationEvent.create!(
      line: car.line,
      car:,
      event_type: ACTION_EVENT_TYPES.fetch(action),
      payload: {
        action:,
        reason:,
        car_status: car.status,
        car_position: car.position.to_f
      },
      occurred_at: Time.current
    )
  end

  def inferred_direction
    car.position.to_f >= 0.5 ? "down" : "up"
  end
end
