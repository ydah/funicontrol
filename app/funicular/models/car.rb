class Car < Funicular::Model
  def dispatch(action:, reason: nil, current_line_id: nil, &block)
    path = current_line_id ? "/api/lines/#{current_line_id}/dispatch" : "/api/cars/#{id}/dispatch"
    Funicular::HTTP.post(path, {
      action: action,
      reason: reason,
      car_id: id,
      line_id: current_line_id || line_id,
      code: code
    }) do |response|
      block.call(response) if block
    end
  end
end
