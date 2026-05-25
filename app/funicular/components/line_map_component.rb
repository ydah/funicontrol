class LineMapComponent < ApplicationComponent
  MAP_WIDTH = 900.0
  MAP_HEIGHT = 260.0
  MAP_MARGIN_X = 56.0
  MAP_MARGIN_Y = 54.0

  styles do
    map "line-map"
    station "station-marker"
    car base: "map-car", variants: {
      idle: "car-idle",
      running: "car-running",
      slow: "car-slow",
      stopped: "car-stopped",
      emergency: "car-emergency",
      inspection_required: "car-inspection_required",
      maintenance: "car-maintenance"
    }
  end

  def component_mounted
    mount_canvas_renderer
  end

  def component_updated
    if @renderer && JS.global[:FunicontrolLineMap]
      JS.global[:FunicontrolLineMap].update(@renderer, JS::Bridge.to_js(map_payload))
    else
      mount_canvas_renderer
    end
  end

  def component_will_unmount
    JS.global[:FunicontrolLineMap].unmount(@renderer) if @renderer && JS.global[:FunicontrolLineMap]
    @renderer = nil
  end

  def render
    div(class: s.map) do
      canvas(class: "line-map-canvas", ref: :canvas, width: "900", height: "260")
      div(class: "canvas-fallback") { "Canvas unavailable" }
      div(class: "track-line")
      (props[:track_segments] || []).each do |segment|
        next unless value(segment, :kind).to_s == "passing_loop"

        div(class: "passing-loop-marker", style: segment_style(segment)) do
          span { value(segment, :name).to_s }
        end
      end
      (props[:stations] || []).each do |station|
        status = value(station, :status).to_s
        station_class = "#{s.station} station-#{status}"
        div(class: station_class, style: map_point_style(station)) do
          span(class: "station-dot")
          span(class: "station-label") { value(station, :name).to_s }
          span(class: "station-state") { status }
        end
      end
      (props[:cars] || []).each do |car|
        status = value(car, :status).to_s
        selected = object_id(car) == props[:selected_car_id].to_i
        car_class = selected ? "#{s.car(status.to_sym)} selected" : s.car(status.to_sym)
        car_class = "#{car_class} stale-car" if value(car, :stale).to_s == "true"
        div(class: car_class, style: map_point_style(car), onclick: -> { select_car(car) }) do
          span(class: "car-code") { "#{direction_arrow(car)} #{value(car, :name)}" }
          span(class: "car-meta") { "#{status_label(status)} #{percent_position(car)}%" }
        end
      end
    end
  end

  def map_payload
    {
      stations: serialize_map_collection(props[:stations] || []),
      cars: serialize_map_collection(props[:cars] || []),
      track_segments: serialize_track_segments(props[:track_segments] || [])
    }
  end

  def mount_canvas_renderer
    return unless refs[:canvas]
    return unless JS.global[:FunicontrolLineMap]

    @renderer = JS.global[:FunicontrolLineMap].mount(refs[:canvas], JS::Bridge.to_js(map_payload))
  end

  def map_point_style(item)
    point = map_coordinates_for_position(numeric_value(value(item, :position)))
    "left: #{point[:map_x_percent].round(1)}%; top: #{point[:map_y_percent].round(1)}%;"
  end

  def select_car(car)
    props[:on_select]&.call(object_id(car))
  end

  def direction_arrow(car)
    direction = value(car, :direction).to_s
    return "v" if direction == "down"
    return "^" if direction == "up"

    "-"
  end

  def segment_style(segment)
    start_position = numeric_value(value(segment, :start_position))
    end_position = numeric_value(value(segment, :end_position))
    middle = (start_position + end_position) / 2.0
    point = map_coordinates_for_position(middle)
    "left: #{point[:map_x_percent].round(1)}%; top: #{point[:map_y_percent].round(1)}%;"
  end

  def serialize_map_collection(items)
    (items || []).map do |item|
      position = numeric_value(value(item, :position))
      {
        id: object_id(item),
        name: value(item, :name),
        position: position,
        direction: value(item, :direction),
        speed: numeric_value(value(item, :speed)),
        status: value(item, :status)
      }.merge(map_coordinates_for_position(position))
    end
  end

  def serialize_track_segments(items)
    (items || []).map do |segment|
      start_position = numeric_value(value(segment, :start_position))
      end_position = numeric_value(value(segment, :end_position))
      start_point = map_coordinates_for_position(start_position)
      end_point = map_coordinates_for_position(end_position)
      {
        id: object_id(segment),
        name: value(segment, :name),
        kind: value(segment, :kind),
        start_position: start_position,
        end_position: end_position,
        start_map_x_percent: start_point[:map_x_percent],
        start_map_y_percent: start_point[:map_y_percent],
        end_map_x_percent: end_point[:map_x_percent],
        end_map_y_percent: end_point[:map_y_percent],
        speed_limit: numeric_value(value(segment, :speed_limit))
      }
    end
  end

  def map_coordinates_for_position(position)
    clamped = position.to_f.clamp(0.0, 1.0)
    x = MAP_MARGIN_X + (MAP_WIDTH - MAP_MARGIN_X * 2) * clamped
    y = MAP_HEIGHT - MAP_MARGIN_Y - (MAP_HEIGHT - MAP_MARGIN_Y * 2) * clamped
    {
      map_x_percent: (x / MAP_WIDTH * 100).round(3),
      map_y_percent: (y / MAP_HEIGHT * 100).round(3)
    }
  end
end
