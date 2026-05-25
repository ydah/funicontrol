class LineSerializer < ApplicationSerializer
  def as_json
    {
      id: record.id,
      name: record.name,
      slug: record.slug,
      status: record.status,
      description: record.description,
      created_at: timestamp(record.created_at),
      updated_at: timestamp(record.updated_at)
    }.tap do |json|
      json[:stations] = StationSerializer.render_collection(record.stations) if options[:include_stations]
      json[:cars] = CarSerializer.render_collection(record.cars) if options[:include_cars]
      json[:open_incidents_count] = record.incidents.where.not(status: "resolved").count if options[:include_counts]
      json[:running_cars_count] = record.cars.where(status: %w[running slow]).count if options[:include_counts]
      if options[:include_recent_events]
        json[:recent_events] = OperationEventSerializer.render_collection(
          record.operation_events.order(occurred_at: :desc, id: :desc).limit(10)
        )
      end
    end
  end
end
