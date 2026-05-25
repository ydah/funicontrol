class CarSerializer < ApplicationSerializer
  def as_json
    {
      id: record.id,
      line_id: record.line_id,
      name: record.name,
      code: record.code,
      position: decimal(record.position),
      direction: record.direction,
      speed: decimal(record.speed),
      status: record.status,
      last_seen_at: timestamp(record.last_seen_at),
      created_at: timestamp(record.created_at),
      updated_at: timestamp(record.updated_at)
    }
  end
end
