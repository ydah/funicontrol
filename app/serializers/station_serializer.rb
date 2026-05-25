class StationSerializer < ApplicationSerializer
  def as_json
    {
      id: record.id,
      line_id: record.line_id,
      name: record.name,
      position: decimal(record.position),
      status: record.status,
      passenger_level: record.passenger_level,
      created_at: timestamp(record.created_at),
      updated_at: timestamp(record.updated_at)
    }
  end
end
