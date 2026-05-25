class ReplayPanelComponent < ApplicationComponent
  use_suspense :replay_payload,
    ->(resolve, reject) {
      line_id = SelectedLineStore.where.value || "1"
      Funicular::HTTP.get("/api/lines/#{line_id}?fresh=#{Time.now.to_i}") do |line_response|
        if line_response.ok
          line = Line.new(line_response.data)
          Funicular::HTTP.get_cached("/api/lines/#{line_id}/operation_events?limit=200") do |response|
            if response.ok
              resolve.call({ line: line, events: response.data.reverse })
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
      patch(
        line: line,
        stations: stations,
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
      base_cars: [],
      replay_cars: [],
      events: [],
      index: 0,
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
            span(class: "muted") { "#{state.index} / #{state.events.length}" }
          end
          div(class: "row") do
            button(class: "button primary", onclick: :play) { state.is_playing ? "Playing" : "Play" }
            button(class: "button secondary", onclick: :stop) { "Stop" }
            button(class: "button secondary", onclick: :reset) { "Reset" }
            button(class: "button secondary", onclick: :step_once) { "Step" }
          end
        end
        component(LineMapComponent,
          line: state.line,
          stations: state.stations,
          cars: state.replay_cars,
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
    patch(replay_cars: clone_cars(state.base_cars), index: 0)
  end

  def step_once
    apply_next_event
  end

  def schedule_next
    @timer_id = JS.global.setTimeout(800) do
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
    patch(replay_cars: next_cars, index: state.index + 1)
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

  def visible_events
    limit_collection(limit_collection(state.events, state.index).reverse, 50)
  end

  def clone_cars(cars)
    cars.map { |car| car.is_a?(Hash) ? car.merge({}) : car }
  end
end
