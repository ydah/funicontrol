class AdvanceCarPositions
  Result = Data.define(:cars, :events)
  NORMAL_SPEED = 0.02
  SLOW_SPEED = 0.008
  MIN_POSITION_EVENT_SECONDS = 5
  MIN_POSITION_EVENT_DELTA = 0.03
  POSITION_EVENT_LIMIT_PER_LINE = 1_000
  ARRIVAL_EPSILON = 0.006
  STATION_APPROACH_DISTANCE = 0.12
  MIN_CAR_DISTANCE = 0.08
  MAX_ELAPSED_SECONDS = 5

  def self.call(line:)
    new(line:).call
  end

  def initialize(line:)
    @line = line
    @now = Time.current
    @events = []
    @updated_cars = []
  end

  def call
    cars = Car.where(line_id: line.id).order(:code).to_a
    cars.each do |car|
      car.with_lock do
        car.reload
        release_dwell_if_ready(car)
        apply_spacing_rule(car, cars)
        next unless car.status.in?(%w[running slow])

        update_car_position(car)
      end
    end
    prune_position_events
    LineBroadcaster.broadcast_cars_updated(line:, cars: @updated_cars, events: @events) if @updated_cars.any?
    Result.new(cars: @updated_cars, events: @events)
  end

  private

  attr_reader :line, :now

  def update_car_position(car)
    previous_position = car.position.to_f
    effective_speed = speed_for(car)
    next_position = previous_position + position_delta(car, effective_speed)
    next_direction = car.direction
    arrival_station = crossed_station(previous_position, next_position, car.direction)

    if arrival_station
      next_position = arrival_station.position.to_f
      next_direction = "idle"
      car.update!(
        position: next_position,
        status: "stopped",
        direction: next_direction,
        speed: 0.0,
        dwell_until: dwell_until_for(arrival_station),
        last_seen_at: now
      )
      @updated_cars << car
      @events << record_arrival_event(car, arrival_station)
      return
    end

    if next_position >= 1.0
      next_position = 1.0
      next_direction = "down"
    elsif next_position <= 0.0
      next_position = 0.0
      next_direction = "up"
    end

    next_status = (effective_speed <= SLOW_SPEED) ? "slow" : car.status
    car.update!(
      position: next_position,
      direction: next_direction,
      speed: effective_speed,
      status: next_status,
      last_seen_at: now
    )
    @updated_cars << car

    @events << record_position_event(car, previous_position) if record_position_event?(car, previous_position)
  end

  def record_position_event(car, previous_position)
    RecordOperationEvent.call(
      line: car.line,
      car:,
      event_type: "car_position_updated",
      payload: car_payload(car).merge(
        previous_position: previous_position,
        position: car.position.to_f,
        direction: car.direction,
        speed: car.speed.to_f,
        status: car.status
      ),
      occurred_at: now
    )
  end

  def record_arrival_event(car, station)
    RecordOperationEvent.call(
      line: car.line,
      car:,
      station:,
      event_type: "car_arrived_station",
      payload: car_payload(car).merge(
        station_id: station.id,
        station_name: station.name,
        dwell_until: car.dwell_until&.iso8601
      ),
      occurred_at: now
    )
  end

  def record_departure_event(car, station)
    RecordOperationEvent.call(
      line: car.line,
      car:,
      station:,
      event_type: "car_departed_station",
      payload: car_payload(car).merge(
        station_id: station.id,
        station_name: station.name
      ),
      occurred_at: now
    )
  end

  def position_delta(car, effective_speed)
    delta = effective_speed * elapsed_seconds(car)
    (car.direction == "down") ? -delta : delta
  end

  def elapsed_seconds(car)
    last_seen = car.last_seen_at
    return 1.0 unless last_seen

    (now - last_seen).clamp(0.2, MAX_ELAPSED_SECONDS)
  end

  def release_dwell_if_ready(car)
    return unless car.status == "stopped"
    return unless car.dwell_until && car.dwell_until <= now

    station = nearest_station(car.position)
    car.update!(
      status: "running",
      direction: inferred_direction(car),
      speed: NORMAL_SPEED,
      operation_mode: "auto",
      dwell_until: nil,
      last_seen_at: now
    )
    @updated_cars << car
    @events << record_departure_event(car, station) if station
  end

  def apply_spacing_rule(car, cars)
    return unless car.status.in?(%w[running slow])

    nearest = cars.reject { |other| other.id == car.id }.min_by { |other| (other.position.to_f - car.position.to_f).abs }
    return unless nearest

    distance = (nearest.position.to_f - car.position.to_f).abs
    return unless distance < MIN_CAR_DISTANCE

    car.update!(status: "slow", speed: SLOW_SPEED, last_seen_at: now)
    @updated_cars << car
    @events << record_spacing_event(car, nearest, distance) unless recent_spacing_warning?(car, nearest)
  end

  def record_spacing_event(car, other_car, distance)
    RecordOperationEvent.call(
      line: car.line,
      car:,
      event_type: "car_distance_warning",
      payload: car_payload(car).merge(
        other_car_id: other_car.id,
        other_car_code: other_car.code,
        distance: distance.round(4)
      ),
      occurred_at: now
    )
  end

  def recent_spacing_warning?(car, other_car)
    car.line.operation_events.where(event_type: "car_distance_warning", car_id: [car.id, other_car.id])
      .where("occurred_at >= ?", 30.seconds.ago(now))
      .exists?
  end

  def speed_for(car)
    speed = (car.status == "slow") ? SLOW_SPEED : NORMAL_SPEED
    speed = [speed, weather_speed_limit].compact.min
    speed = [speed, track_speed_limit(car.position)].compact.min
    [speed, station_speed_limit(car.position)].compact.min
  end

  def weather_speed_limit
    case line.weather_condition
    when "wind", "fog", "snow"
      0.01
    when "rain"
      0.014
    end
  end

  def track_speed_limit(position)
    line.track_segments.find { |segment| segment.speed_limit && segment.covers?(position) }&.speed_limit&.to_f
  end

  def station_speed_limit(position)
    station = line.stations.find { |candidate| (candidate.position.to_f - position.to_f).abs <= STATION_APPROACH_DISTANCE }
    return unless station

    if station.status.in?(%w[alert closed]) || station.passenger_level.to_i >= 80
      SLOW_SPEED
    elsif station.status == "crowded" || station.passenger_level.to_i >= 60
      0.012
    end
  end

  def crossed_station(previous_position, next_position, direction)
    return nil if direction == "idle"

    line.stations.find do |station|
      station_position = station.position.to_f
      next if (station_position - previous_position).abs <= ARRIVAL_EPSILON

      if direction == "down"
        station_position.between?(next_position, previous_position)
      else
        station_position.between?(previous_position, next_position)
      end
    end
  end

  def dwell_until_for(station)
    seconds = 3
    seconds += 2 if station.passenger_level.to_i >= 60 || station.status == "crowded"
    seconds += 4 if station.status == "alert"
    now + seconds.seconds
  end

  def nearest_station(position)
    line.stations.min_by { |station| (station.position.to_f - position.to_f).abs }
  end

  def inferred_direction(car)
    (car.position.to_f >= 0.5) ? "down" : "up"
  end

  def record_position_event?(car, previous_position)
    last_event = car.operation_events.where(event_type: "car_position_updated").reverse_chronological.first
    return true unless last_event
    return true if (now - last_event.occurred_at) >= MIN_POSITION_EVENT_SECONDS

    (car.position.to_f - last_event.payload["position"].to_f).abs >= MIN_POSITION_EVENT_DELTA ||
      (car.position.to_f - previous_position).abs >= MIN_POSITION_EVENT_DELTA
  end

  def prune_position_events
    stale_ids = line.operation_events.where(event_type: "car_position_updated")
      .reverse_chronological
      .offset(POSITION_EVENT_LIMIT_PER_LINE)
      .pluck(:id)
    OperationEvent.where(id: stale_ids).delete_all if stale_ids.any?
  end

  def car_payload(car)
    {
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
