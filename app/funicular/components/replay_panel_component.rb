class ReplayPanelComponent < ApplicationComponent
  use_suspense :replay_payload,
    ->(resolve, reject) {
      line_id = SelectedLineStore.where.value || "1"
      Funicular::HTTP.get("/api/lines/#{line_id}?fresh=#{Time.now.to_i}") do |line_response|
        if line_response.ok
          line = Line.new(line_response.data)
          Funicular::HTTP.get_cached("/api/lines/#{line_id}/operation_events?limit=200&order=asc") do |response|
            if response.ok
              resolve.call({ line: line, events: response.data })
            else
              reject.call(response.error_message)
            end
          end
        else
          reject.call(line_response.error_message)
        end
      end
    },
    on_resolve: ->(payload) {
      line = payload[:line] || payload["line"]
      events = payload[:events] || payload["events"] || []
      stations = value(line, :stations) || []
      cars = value(line, :cars) || []
      track_segments = value(line, :track_segments) || []
      patch(
        line: line,
        stations: stations,
        replay_stations: clone_items(stations),
        track_segments: track_segments,
        base_cars: cars,
        replay_cars: clone_cars(cars),
        events: events,
        index: 0,
        is_loading: false
      )
    }

  def initialize_state
    {
      line: nil,
      stations: [],
      replay_stations: [],
      track_segments: [],
      base_cars: [],
      replay_cars: [],
      events: [],
      index: 0,
      speed_ms: 800,
      is_playing: false,
      is_loading: true,
      error: nil
    }
  end

  def component_will_unmount
    JS.global.clearTimeout(@timer_id) if @timer_id
  end

  def render
    div(class: "replay-layout") do
      suspense(
        fallback: -> { p(class: "muted") { "Loading replay..." } },
        error: ->(error) { p(class: "form-error") { error.to_s } }
      ) do
        div(class: "panel") do
          div(class: "row spread") do
            h3 { value(state.line, :name).to_s }
            span(class: "muted") { "#{state.index} / #{state.events.length} / #{diff_count} diffs" }
          end
          div(class: "row") do
            button(class: "button primary", onclick: :play) { state.is_playing ? "Playing" : "Play" }
            button(class: "button secondary", onclick: :stop) { "Stop" }
            button(class: "button secondary", onclick: :reset) { "Reset" }
            button(class: "button secondary", onclick: :step_once) { "Step" }
            select(class: "input compact-input", value: state.speed_ms.to_s, onchange: ->(event) { patch(speed_ms: event.target[:value].to_i) }) do
              option(value: "1600") { "0.5x" }
              option(value: "800") { "1x" }
              option(value: "400") { "2x" }
            end
          end
        end
        component(LineMapComponent,
          line: state.line,
          stations: state.replay_stations,
          cars: state.replay_cars,
          track_segments: state.track_segments,
          selected_car_id: nil
        )
        component(OperationLogComponent, events: visible_events, scroll_key: "replay")
      end
    end
  end

  def play
    return if state.is_playing

    patch(is_playing: true)
    schedule_next
  end

  def stop
    JS.global.clearTimeout(@timer_id) if @timer_id
    @timer_id = nil
    patch(is_playing: false)
  end

  def reset
    stop
    patch(replay_cars: clone_cars(state.base_cars), replay_stations: clone_items(state.stations), index: 0)
  end

  def step_once
    apply_next_event
  end

  def schedule_next
    @timer_id = JS.global.setTimeout(state.speed_ms.to_i) do
      if state.is_playing
        applied = apply_next_event
        applied ? schedule_next : stop
      end
    end
  end

  def apply_next_event
    return false if state.index >= state.events.length

    event = state.events[state.index]
    next_cars = apply_event_to_cars(state.replay_cars, event)
    next_stations = apply_event_to_stations(state.replay_stations, event)
    patch(replay_cars: next_cars, replay_stations: next_stations, index: state.index + 1)
    true
  end

  def apply_event_to_cars(cars, event)
    car_id = value(event, :car_id)
    return cars unless car_id

    payload = value(event, :payload) || {}
    cars.map do |car|
      next car unless object_id(car) == car_id.to_i

      car.merge(
        "position" => payload["position"] || payload["car_position"] || value(car, :position),
        "direction" => payload["direction"] || value(car, :direction),
        "speed" => payload["speed"] || value(car, :speed),
        "status" => payload["status"] || payload["car_status"] || value(car, :status)
      )
    end
  end

  def apply_event_to_stations(stations, event)
    station_id = value(event, :station_id)
    return stations unless station_id

    payload = value(event, :payload) || {}
    stations.map do |station|
      next station unless object_id(station) == station_id.to_i

      station.merge(
        "status" => payload["status"] || payload["station_status"] || value(station, :status),
        "passenger_level" => payload["passenger_level"] || value(station, :passenger_level)
      )
    end
  end

  def visible_events
    limit_collection(limit_collection(state.events, state.index).reverse, 50)
  end

  def clone_cars(cars)
    cars.map { |car| car.is_a?(Hash) ? car.merge({}) : car }
  end

  def clone_items(items)
    items.map { |item| item.is_a?(Hash) ? item.merge({}) : item }
  end

  def diff_count
    count = 0
    state.replay_cars.each do |car|
      live = state.base_cars.find { |candidate| object_id(candidate) == object_id(car) }
      count += 1 if live && (value(live, :position).to_s != value(car, :position).to_s || value(live, :status).to_s != value(car, :status).to_s)
    end
    count
  end
end
