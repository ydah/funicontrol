class LineBroadcaster
  class << self
    def broadcast_car_position_updated(line:, car:, event:)
      broadcast(line, {
        type: "car_position_updated",
        car: CarSerializer.render(car),
        event: OperationEventSerializer.render(event)
      })
    end

    def broadcast_operation_event(line:, car:, event:)
      broadcast(line, {
        type: "operation_event",
        car: CarSerializer.render(car),
        event: OperationEventSerializer.render(event)
      })
    end

    def broadcast_incident_created(line:, incident:, event:)
      broadcast(line, {
        type: "incident_created",
        incident: IncidentSerializer.render(incident),
        event: OperationEventSerializer.render(event)
      })
    end

    def broadcast_incident_updated(line:, incident:, event:)
      broadcast(line, {
        type: "incident_updated",
        incident: IncidentSerializer.render(incident),
        event: OperationEventSerializer.render(event)
      })
    end

    def broadcast_comment_created(line:, comment:, event:)
      broadcast(line, {
        type: "comment_created",
        incident_id: comment.incident_id,
        comment: IncidentCommentSerializer.render(comment),
        event: OperationEventSerializer.render(event)
      })
    end

    def broadcast_station_updated(line:, station:, event:)
      broadcast(line, {
        type: "station_updated",
        station: StationSerializer.render(station),
        event: OperationEventSerializer.render(event)
      })
    end

    def broadcast_line_status_updated(line:, event:)
      broadcast(line, {
        type: "line_status_updated",
        line: LineSerializer.render(line, include_stations: true, include_cars: true),
        event: OperationEventSerializer.render(event)
      })
    end

    private

    def broadcast(line, payload)
      ActionCable.server.broadcast("line_#{line.id}", payload)
    end
  end
end
