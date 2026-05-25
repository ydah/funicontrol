class LineBroadcaster
  class << self
    def broadcast_car_position_updated(line:, car:, event:)
      broadcast(line, LineBroadcastPayload.car_position_updated(car:, event:))
    end

    def broadcast_cars_updated(line:, cars:, events:)
      broadcast(line, LineBroadcastPayload.cars_updated(cars:, events:))
    end

    def broadcast_operation_event(line:, car:, event:)
      broadcast(line, LineBroadcastPayload.operation_event(car:, event:))
    end

    def broadcast_incident_created(line:, incident:, event:)
      broadcast(line, LineBroadcastPayload.incident_created(incident:, event:))
    end

    def broadcast_incident_updated(line:, incident:, event:)
      broadcast(line, LineBroadcastPayload.incident_updated(incident:, event:))
    end

    def broadcast_comment_created(line:, comment:, event:)
      broadcast(line, LineBroadcastPayload.comment_created(comment:, event:))
    end

    def broadcast_station_updated(line:, station:, event:)
      broadcast(line, LineBroadcastPayload.station_updated(station:, event:))
    end

    def broadcast_line_status_updated(line:, event:)
      broadcast(line, LineBroadcastPayload.line_status_updated(line:, event:))
    end

    def broadcast_operator_message(line:, event:)
      broadcast(line, LineBroadcastPayload.operator_message(event:))
    end

    private

    def broadcast(line, payload)
      ActionCable.server.broadcast("line_#{line.id}", payload)
    rescue => error
      Rails.logger.warn(
        message: "line_broadcast_failed",
        line_id: line.id,
        payload_type: payload[:type] || payload["type"],
        error_class: error.class.name,
        error_message: error.message
      )
      nil
    end
  end
end
