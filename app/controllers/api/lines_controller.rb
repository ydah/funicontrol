module Api
  class LinesController < ApplicationController
    def index
      lines = Line.includes(:cars, :incidents, :operation_events).order(:id)
      render json: LineSerializer.render_collection(lines, include_counts: true, include_recent_events: true)
    end

    def show
      line = Line.includes(:stations, :cars).find(params[:id])
      render json: LineSerializer.render(line, include_stations: true, include_cars: true)
    end

    def suspend
      update_status("suspend")
    end

    def resume
      update_status("resume")
    end

    def dispatch_car
      line = Line.find(params[:id])
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
      line = Line.find(params[:id])
      result = SetLineStatus.call(line:, action:, reason: params[:reason])
      LineBroadcaster.broadcast_line_status_updated(line: result.line, event: result.event)

      render json: {
        line: LineSerializer.render(result.line, include_stations: true, include_cars: true),
        event: OperationEventSerializer.render(result.event)
      }
    end

    def dispatch_car_for(line)
      code = dispatch_payload[:code]
      car = line.cars.find_by(code:) if code.present?
      car ||= line.cars.find_by(id: dispatch_payload[:car_id])
      car ||= line.cars.order(:code).first
      car || raise(ActiveRecord::RecordNotFound, "No cars are available for line #{line.id}")
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
