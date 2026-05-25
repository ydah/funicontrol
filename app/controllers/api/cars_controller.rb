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
      Car.find(params[:id])
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
