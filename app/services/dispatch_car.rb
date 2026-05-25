class DispatchCar
  Result = Data.define(:car, :event, :events)

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
      car.with_lock do
        @events = []
        @now = Time.current
        apply_action!
        event = record_event!(ACTION_EVENT_TYPES.fetch(action))
        Result.new(car:, event:, events: @events)
      end
    end
  end

  private

  attr_reader :car, :action, :reason, :now

  def apply_action!
    raise ArgumentError, "Unknown dispatch action: #{action}" unless ACTION_EVENT_TYPES.key?(action)
    validate_reason!
    validate_line_can_dispatch!

    case action
    when "start"
      raise ArgumentError, "Emergency must be recovered before start" if car.status == "emergency"
      raise ArgumentError, "Inspection must be cleared before start" if car.status == "inspection_required"

      record_departure_if_needed
      car.update!(status: "running", speed: 0.02, direction: inferred_direction, operation_mode: "manual", dwell_until: nil, last_seen_at: now)
    when "stop"
      car.update!(status: "stopped", speed: 0.0, direction: "idle", dwell_until: nil, last_seen_at: now)
    when "slow"
      car.update!(status: "slow", speed: 0.008, direction: (car.direction == "idle") ? inferred_direction : car.direction, operation_mode: "manual", dwell_until: nil, last_seen_at: now)
    when "emergency_stop"
      car.update!(status: "emergency", speed: 0.0, direction: "idle", operation_mode: "inspection", dwell_until: nil, last_seen_at: now)
    when "recover"
      next_status = (car.status == "emergency") ? "inspection_required" : "stopped"
      next_mode = (next_status == "inspection_required") ? "inspection" : "manual"
      car.update!(status: next_status, speed: 0.0, direction: "idle", operation_mode: next_mode, dwell_until: nil, last_seen_at: now)
    end
  end

  def record_event!(event_type, station: nil, payload: {})
    event = RecordOperationEvent.call(
      line: car.line,
      car:,
      station:,
      event_type:,
      payload: car_payload.merge(payload),
      occurred_at: now
    )
    @events << event
    event
  end

  def inferred_direction
    (car.position.to_f >= 0.5) ? "down" : "up"
  end

  def validate_reason!
    return unless action == "emergency_stop"
    return if reason.to_s.strip.present?

    raise ArgumentError, "Reason is required for emergency stop"
  end

  def validate_line_can_dispatch!
    return unless action.in?(%w[start slow])
    return if car.line.status == "normal"

    raise ArgumentError, "Car dispatch is disabled while line is #{car.line.status}"
  end

  def record_departure_if_needed
    station = nearest_station
    return unless station

    record_event!(
      "car_departed_station",
      station:,
      payload: {
        station_id: station.id,
        station_name: station.name
      }
    )
  end

  def nearest_station
    car.line.stations.find do |station|
      (station.position.to_f - car.position.to_f).abs <= 0.01
    end
  end

  def car_payload
    {
      action:,
      reason:,
      car_id: car.id,
      car_code: car.code,
      car_name: car.name,
      car_status: car.status,
      status: car.status,
      car_position: car.position.to_f,
      position: car.position.to_f,
      direction: car.direction,
      speed: car.speed.to_f,
      operation_mode: car.operation_mode
    }
  end
end
