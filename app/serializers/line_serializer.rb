class LineSerializer < ApplicationSerializer
  def as_json
    {
      id: record.id,
      name: record.name,
      slug: record.slug,
      status: record.status,
      weather_condition: record.weather_condition,
      passenger_satisfaction_score: record.passenger_satisfaction_score,
      description: record.description,
      created_at: timestamp(record.created_at),
      updated_at: timestamp(record.updated_at)
    }.tap do |json|
      json[:stations] = StationSerializer.render_collection(record.stations) if options[:include_stations]
      json[:cars] = CarSerializer.render_collection(record.cars) if options[:include_cars]
      json[:track_segments] = TrackSegmentSerializer.render_collection(record.track_segments) if options[:include_track_segments]
      if options[:include_counts]
        json[:open_incidents_count] = option_count(:open_incidents_counts) { record.incidents.where.not(status: "resolved").count }
        json[:running_cars_count] = option_count(:running_cars_counts) { record.cars.where(status: %w[running slow]).count }
        json[:critical_incidents_count] = option_count(:critical_incidents_counts) { record.open_critical_incidents_count }
        json[:sla_breached_incidents_count] = option_count(:sla_breached_incidents_counts) { sla_breached_incidents_count }
      end
      if options[:include_recent_events]
        events = options.fetch(:recent_events_by_line, {})[record.id] || record.operation_events.important.reverse_chronological.limit(10)
        json[:recent_events] = OperationEventSerializer.render_collection(events.first(10))
      end
    end
  end

  private

  def option_count(key)
    counts = options[key]
    return counts.fetch(record.id, 0) if counts

    yield
  end

  def sla_breached_incidents_count
    record.incidents.where(status: %w[open acknowledged], severity: %w[high critical]).count do |incident|
      incident.sla_status == "breached"
    end
  end
end
