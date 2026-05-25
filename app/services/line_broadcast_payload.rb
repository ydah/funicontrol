class LineBroadcastPayload
  class << self
    def car_position_updated(car:, event:)
      base("car_position_updated", event).merge(
        car: CarSerializer.render(car),
        event: OperationEventSerializer.render(event)
      )
    end

    def cars_updated(cars:, events:)
      last_event = events.compact.max_by(&:id)
      base("cars_updated", last_event).merge(
        cars: CarSerializer.render_collection(cars),
        events: OperationEventSerializer.render_collection(events.compact)
      )
    end

    def operation_event(car:, event:)
      base("operation_event", event).merge(
        car: CarSerializer.render(car),
        event: OperationEventSerializer.render(event)
      )
    end

    def incident_created(incident:, event:)
      base("incident_created", event).merge(
        incident: IncidentSerializer.render(incident),
        event: OperationEventSerializer.render(event)
      )
    end

    def incident_updated(incident:, event:)
      base("incident_updated", event).merge(
        incident: IncidentSerializer.render(incident),
        event: OperationEventSerializer.render(event)
      )
    end

    def comment_created(comment:, event:)
      base("comment_created", event).merge(
        incident_id: comment.incident_id,
        comment: IncidentCommentSerializer.render(comment),
        event: OperationEventSerializer.render(event)
      )
    end

    def station_updated(station:, event:)
      base("station_updated", event).merge(
        station: StationSerializer.render(station),
        event: OperationEventSerializer.render(event)
      )
    end

    def line_status_updated(line:, event:)
      base("line_status_updated", event).merge(
        line: LineSerializer.render(line, include_stations: true, include_cars: true, include_track_segments: true),
        event: OperationEventSerializer.render(event)
      )
    end

    def operator_message(event:)
      base("operator_message_sent", event).merge(
        event: OperationEventSerializer.render(event)
      )
    end

    private

    def base(type, event)
      {
        type:,
        event_type: event&.event_type || type,
        sequence: event&.id
      }
    end
  end
end
