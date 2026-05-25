class TrackSegmentSerializer < ApplicationSerializer
  def as_json
    {
      id: record.id,
      line_id: record.line_id,
      name: record.name,
      kind: record.kind,
      start_position: decimal(record.start_position),
      end_position: decimal(record.end_position),
      speed_limit: decimal(record.speed_limit),
      gradient: decimal(record.gradient),
      created_at: timestamp(record.created_at),
      updated_at: timestamp(record.updated_at)
    }
  end
end
