class LineChannel < ApplicationCable::Channel
  def subscribed
    return reject unless line

    stream_from stream_name
  end

  def perform_action(data)
    if data["action"].to_s == "dispatch"
      dispatch_command(data)
    elsif data["action"].to_s == "operator_message"
      operator_message(data)
    else
      super
    end
  end

  def dispatch_car(data)
    dispatch_command(data)
  end

  def operator_message(data)
    message = data["message"].to_s.strip
    raise ArgumentError, "message is required" if message.blank?

    event = RecordOperationEvent.call(
      line:,
      event_type: "operator_message_sent",
      payload: {
        message:,
        operator_name: data["operator_name"].presence || "operator"
      },
      occurred_at: Time.current
    )
    LineBroadcaster.broadcast_operator_message(line:, event:)
  rescue ArgumentError => e
    transmit({type: "dispatch_error", errors: {base: [e.message]}})
  end

  private

  def dispatch_command(data)
    car = dispatch_car_for(data)
    result = DispatchCar.call(
      car:,
      action: dispatch_action(data),
      reason: data["reason"]
    )

    LineBroadcaster.broadcast_operation_event(line:, car: result.car, event: result.event)
  rescue ActiveRecord::RecordNotFound, ArgumentError => e
    transmit({type: "dispatch_error", errors: {base: [e.message]}})
  end

  def dispatch_car_for(data)
    requested_id = data["car_id"] || data[:car_id]
    requested_code = data["code"] || data[:code]
    raise ArgumentError, "car_id or code is required" if requested_id.blank? && requested_code.blank?

    if requested_code
      car = line.cars.find_by(code: requested_code)
      return car if car
    end

    car = line.cars.find_by(id: requested_id)
    return car if car

    raise ActiveRecord::RecordNotFound, "Car not found for line #{line.id}"
  end

  def dispatch_action(data)
    data["dispatch_action"] || data["command"] || data["car_action"] || data["operation"]
  end

  def line
    @line ||= if params[:line_id].to_s.match?(/\A\d+\z/)
      Line.find_by(id: params[:line_id])
    else
      Line.find_by(slug: params[:line_id])
    end
  end

  def stream_name
    "line_#{line.id}"
  end
end
