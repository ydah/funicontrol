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
      operation_mode: record.operation_mode,
      dwell_until: timestamp(record.dwell_until),
      last_seen_at: timestamp(record.last_seen_at),
      stale: record.stale?,
      next_station: next_station_payload,
      eta_seconds: record.eta_seconds,
      created_at: timestamp(record.created_at),
      updated_at: timestamp(record.updated_at)
    }
  end

  private

  def next_station_payload
    station = record.next_station
    return nil unless station

    {
      id: station.id,
      name: station.name,
      position: decimal(station.position)
    }
  end
end
