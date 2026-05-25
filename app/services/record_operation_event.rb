class RecordOperationEvent
  def self.call(line:, event_type:, car: nil, station: nil, incident: nil, payload: {}, occurred_at: Time.current)
    new(line:, event_type:, car:, station:, incident:, payload:, occurred_at:).call
  end

  def initialize(line:, event_type:, car:, station:, incident:, payload:, occurred_at:)
    @line = line
    @event_type = event_type
    @car = car
    @station = station
    @incident = incident
    @payload = payload || {}
    @occurred_at = occurred_at
  end

  def call
    line.operation_events.create!(
      car:,
      station:,
      incident:,
      event_type:,
      payload: normalized_payload,
      occurred_at:
    )
  end

  private

  attr_reader :line, :event_type, :car, :station, :incident, :payload, :occurred_at

  def normalized_payload
    base_payload.merge(payload).compact
  end

  def base_payload
    {
      line_id: line.id,
      line_status: line.status,
      weather_condition: line.weather_condition,
      passenger_satisfaction_score: line.passenger_satisfaction_score
    }.merge(car_payload).merge(station_payload).merge(incident_payload)
  end

  def car_payload
    return {} unless car

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

  def station_payload
    return {} unless station

    {
      station_id: station.id,
      station_name: station.name,
      station_status: station.status,
      passenger_level: station.passenger_level
    }
  end

  def incident_payload
    return {} unless incident

    {
      incident_id: incident.id,
      incident_status: incident.status,
      severity: incident.severity,
      title: incident.title,
      kind: incident.kind
    }
  end
end
