module Api
  class CarsController < ApplicationController
    def show
      render json: CarSerializer.render(Car.find(params[:id]))
    end

    def dispatch_car
      car = dispatch_car_record
      result = DispatchCar.call(car:, action: dispatch_payload[:action], reason: dispatch_payload[:reason])
      LineBroadcaster.broadcast_operation_event(line: car.line, car: result.car, event: result.event)

      render json: {
        car: CarSerializer.render(result.car),
        event: OperationEventSerializer.render(result.event)
      }
    end

    private

    def dispatch_car_record
      Car.find_by(id: params[:id]) || fallback_dispatch_car || Car.find(params[:id])
    end

    def fallback_dispatch_car
      line = fallback_dispatch_line
      return unless line

      code = dispatch_payload[:code]
      if code.present?
        car = line.cars.find_by(code:)
        return car if car
      end

      line.cars.order(:code).first
    end

    def fallback_dispatch_line
      Line.find_by(id: referer_line_id) ||
        Line.find_by(id: dispatch_payload[:line_id]) ||
        Line.order(:id).first
    end

    def referer_line_id
      request.referer.to_s[%r{/lines/(\d+)}, 1]
    end

    def dispatch_payload
      @dispatch_payload ||= begin
        body = request.request_parameters
        {
        action: body["action"] || body[:action],
        reason: body["reason"] || body[:reason],
        line_id: body["line_id"] || body[:line_id],
        code: body["code"] || body[:code]
        }
      end
    end
  end
end
