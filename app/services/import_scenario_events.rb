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

      line.operation_events.create!(
        event_type:,
        car_id: nullable_id(attributes["car_id"] || attributes[:car_id]),
        station_id: nullable_id(attributes["station_id"] || attributes[:station_id]),
        incident_id: nullable_id(attributes["incident_id"] || attributes[:incident_id]),
        payload: attributes["payload"] || attributes[:payload] || {},
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

  def nullable_id(value)
    value.presence
  end
end
