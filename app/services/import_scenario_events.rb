class ImportScenarioEvents
  def self.call(line:, events:)
    new(line:, events:).call
  end

  def initialize(line:, events:)
    @line = line
    @events = Array(events)
  end

  def call
    @events.map do |attributes|
      event_type = attributes["event_type"] || attributes[:event_type]
      raise ArgumentError, "Unknown event type: #{event_type}" unless event_type.in?(OperationEvent::EVENT_TYPES)

      RecordOperationEvent.call(
        line:,
        event_type:,
        car: find_association(line.cars, attributes["car_id"] || attributes[:car_id]),
        station: find_association(line.stations, attributes["station_id"] || attributes[:station_id]),
        incident: find_association(line.incidents, attributes["incident_id"] || attributes[:incident_id]),
        payload: payload_for(attributes),
        occurred_at: parse_time(attributes["occurred_at"] || attributes[:occurred_at])
      )
    end
  end

  private

  attr_reader :line

  def parse_time(value)
    value.present? ? Time.iso8601(value.to_s) : Time.current
  rescue ArgumentError
    raise ArgumentError, "occurred_at must be an ISO 8601 timestamp"
  end

  def find_association(scope, value)
    return nil if value.blank?

    scope.find(value)
  end

  def payload_for(attributes)
    payload = attributes["payload"] || attributes[:payload] || {}
    return payload.to_unsafe_h if payload.respond_to?(:to_unsafe_h)

    payload
  end
end
