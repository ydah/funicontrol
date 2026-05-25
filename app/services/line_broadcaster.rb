class LineBroadcaster
  class << self
    def broadcast_car_position_updated(line:, car:, event:)
      broadcast(line, {
        type: "car_position_updated",
        event_type: event.event_type,
        sequence: event.id,
        car: CarSerializer.render(car),
        event: OperationEventSerializer.render(event)
      })
    end

    def broadcast_cars_updated(line:, cars:, events:)
      last_event = events.compact.max_by(&:id)
      broadcast(line, {
        type: "cars_updated",
        event_type: "cars_updated",
        sequence: last_event&.id,
        cars: CarSerializer.render_collection(cars),
        events: OperationEventSerializer.render_collection(events.compact)
      })
    end

    def broadcast_operation_event(line:, car:, event:)
      broadcast(line, {
        type: "operation_event",
        event_type: event.event_type,
        sequence: event.id,
        car: CarSerializer.render(car),
        event: OperationEventSerializer.render(event)
      })
    end

    def broadcast_incident_created(line:, incident:, event:)
      broadcast(line, {
        type: "incident_created",
        event_type: event.event_type,
        sequence: event.id,
        incident: IncidentSerializer.render(incident),
        event: OperationEventSerializer.render(event)
      })
    end

    def broadcast_incident_updated(line:, incident:, event:)
      broadcast(line, {
        type: "incident_updated",
        event_type: event.event_type,
        sequence: event.id,
        incident: IncidentSerializer.render(incident),
        event: OperationEventSerializer.render(event)
      })
    end

    def broadcast_comment_created(line:, comment:, event:)
      broadcast(line, {
        type: "comment_created",
        event_type: event.event_type,
        sequence: event.id,
        incident_id: comment.incident_id,
        comment: IncidentCommentSerializer.render(comment),
        event: OperationEventSerializer.render(event)
      })
    end

    def broadcast_station_updated(line:, station:, event:)
      broadcast(line, {
        type: "station_updated",
        event_type: event.event_type,
        sequence: event.id,
        station: StationSerializer.render(station),
        event: OperationEventSerializer.render(event)
      })
    end

    def broadcast_line_status_updated(line:, event:)
      broadcast(line, {
        type: "line_status_updated",
        event_type: event.event_type,
        sequence: event.id,
        line: LineSerializer.render(line, include_stations: true, include_cars: true, include_track_segments: true),
        event: OperationEventSerializer.render(event)
      })
    end

    def broadcast_operator_message(line:, event:)
      broadcast(line, {
        type: "operator_message_sent",
        event_type: event.event_type,
        sequence: event.id,
        event: OperationEventSerializer.render(event)
      })
    end

    private

    def broadcast(line, payload)
      ActionCable.server.broadcast("line_#{line.id}", payload)
    end
  end
end
