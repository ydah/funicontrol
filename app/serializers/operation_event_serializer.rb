class OperationEventSerializer < ApplicationSerializer
  def as_json
    {
      id: record.id,
      line_id: record.line_id,
      car_id: record.car_id,
      station_id: record.station_id,
      incident_id: record.incident_id,
      event_type: record.event_type,
      payload: record.payload || {},
      summary: record.summary,
      important: record.important?,
      occurred_at: timestamp(record.occurred_at),
      created_at: timestamp(record.created_at)
    }
  end
end
