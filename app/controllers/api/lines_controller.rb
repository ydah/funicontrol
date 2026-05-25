module Api
  class LinesController < ApplicationController
    def index
      lines = Line.order(:id).to_a
      line_ids = lines.map(&:id)
      recent_events = OperationEvent.where(line_id: line_ids).important.reverse_chronological.limit(lines.length * 10).group_by(&:line_id)

      render json: LineSerializer.render_collection(
        lines,
        include_counts: true,
        include_recent_events: true,
        open_incidents_counts: Incident.where(line_id: line_ids).where.not(status: "resolved").group(:line_id).count,
        running_cars_counts: Car.where(line_id: line_ids, status: %w[running slow]).group(:line_id).count,
        critical_incidents_counts: Incident.where(line_id: line_ids, status: %w[open acknowledged], severity: "critical").group(:line_id).count,
        recent_events_by_line: recent_events
      )
    end

    def show
      line = Line.includes(:stations, :cars, :track_segments).find(find_line(params[:id]).id)
      render json: LineSerializer.render(line, include_stations: true, include_cars: true, include_track_segments: true)
    end

    def suspend
      update_status("suspend")
    end

    def resume
      update_status("resume")
    end

    def enter_maintenance
      update_status("enter_maintenance")
    end

    def exit_maintenance
      update_status("exit_maintenance")
    end

    def set_weather
      line = find_line(params[:id])
      result = SetLineWeather.call(line:, weather_condition: params[:weather_condition], reason: params[:reason])
      LineBroadcaster.broadcast_line_status_updated(line: result.line, event: result.event)

      render json: {
        line: LineSerializer.render(result.line, include_stations: true, include_cars: true, include_track_segments: true),
        event: OperationEventSerializer.render(result.event)
      }
    end

    def dispatch_car
      line = find_line(params[:id])
      car = dispatch_car_for(line)
      result = DispatchCar.call(car:, action: dispatch_payload[:action], reason: dispatch_payload[:reason])
      LineBroadcaster.broadcast_operation_event(line:, car: result.car, event: result.event)

      render json: {
        car: CarSerializer.render(result.car),
        event: OperationEventSerializer.render(result.event)
      }
    end

    private

    def update_status(action)
      line = find_line(params[:id])
      result = SetLineStatus.call(line:, action:, reason: params[:reason])
      LineBroadcaster.broadcast_line_status_updated(line: result.line, event: result.event)

      render json: {
        line: LineSerializer.render(result.line, include_stations: true, include_cars: true, include_track_segments: true),
        event: OperationEventSerializer.render(result.event)
      }
    end

    def dispatch_car_for(line)
      code = dispatch_payload[:code]
      car_id = dispatch_payload[:car_id]
      raise ArgumentError, "car_id or code is required" if code.blank? && car_id.blank?

      car = line.cars.find_by(code:) if code.present?
      car ||= line.cars.find_by(id: car_id) if car_id.present?
      car || raise(ActiveRecord::RecordNotFound, "Car not found for line #{line.id}")
    end

    def dispatch_payload
      body = request.request_parameters
      {
        action: body["action"] || body[:action],
        reason: body["reason"] || body[:reason],
        car_id: body["car_id"] || body[:car_id],
        code: body["code"] || body[:code]
      }
    end
  end
end
