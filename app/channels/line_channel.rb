class LineChannel < ApplicationCable::Channel
  def subscribed
    reject unless line
    stream_from stream_name
  end

  def perform_action(data)
    if data["action"].to_s == "dispatch"
      dispatch_command(data)
    else
      super
    end
  end

  def dispatch_car(data)
    dispatch_command(data)
  end

  private

  def dispatch_command(data)
    car = dispatch_car_for(data)
    result = DispatchCar.call(
      car:,
      action: data["dispatch_action"] || data["command"] || data["car_action"] || data["operation"],
      reason: data["reason"]
    )

    LineBroadcaster.broadcast_operation_event(line:, car: result.car, event: result.event)
  rescue ActiveRecord::RecordNotFound, ArgumentError => e
    transmit(type: "dispatch_error", errors: { base: [ e.message ] })
  end

  def dispatch_car_for(data)
    requested_id = data["car_id"] || data[:car_id]
    requested_code = data["code"] || data[:code]

    if requested_id
      car = line.cars.find_by(id: requested_id)
      return car if car
    end

    if requested_code
      car = line.cars.find_by(code: requested_code)
      return car if car
    end

    line.cars.order(:code).first || line.cars.first || raise(ActiveRecord::RecordNotFound, "No cars are available for line #{line.id}")
  end

  def line
    @line ||= Line.find_by(id: params[:line_id])
  end

  def stream_name
    "line_#{line.id}"
  end
end
