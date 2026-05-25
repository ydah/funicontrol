class LineShowComponent < ApplicationComponent
  use_suspense :line_payload,
    ->(resolve, reject) {
      Funicular::HTTP.get("/api/lines/#{props[:id]}?fresh=#{Time.now.to_i}") do |response|
        response.ok ? resolve.call(response.data) : reject.call(response.error_message)
      end
    },
    on_resolve: ->(line) {
      cars = value(line, :cars) || []
      stations = value(line, :stations) || []
      selected = cars.empty? ? nil : cars.first
      SelectedLineStore.where.value = props[:id]
      patch(
        line: line,
        cars: cars,
        stations: stations,
        selected_car_id: selection_id(selected),
        selected_car_code: selection_code(selected),
        is_loading: false
      )
    }

  use_suspense :incidents_payload,
    ->(resolve, reject) {
      Funicular::HTTP.get("/api/lines/#{props[:id]}/incidents?fresh=#{Time.now.to_i}") do |response|
        response.ok ? resolve.call(response.data) : reject.call(response.error_message)
      end
    },
    on_resolve: ->(incidents) {
      patch(incidents: incidents)
    }

  use_suspense :stations_payload,
    ->(resolve, reject) {
      Funicular::HTTP.get("/api/lines/#{props[:id]}/stations?fresh=#{Time.now.to_i}") do |response|
        response.ok ? resolve.call(response.data) : reject.call(response.error_message)
      end
    },
    on_resolve: ->(stations) {
      patch(stations: stations)
    }

  use_suspense :events_payload,
    ->(resolve, reject) {
      cache = OperationLogCache.where(line_id: props[:id].to_s)
      cached = cache.all
      patch(operation_events: cached) unless cached.empty?

      Funicular::HTTP.get("/api/lines/#{props[:id]}/operation_events?limit=100&fresh=#{Time.now.to_i}") do |response|
        if response.ok
          cache.replace(response.data)
          resolve.call(response.data)
        elsif cached.empty?
          reject.call(response.error_message)
        else
          resolve.call(cached)
        end
      end
    },
    on_resolve: ->(events) {
      patch(operation_events: events)
    }

  def initialize_state
    {
      line: nil,
      stations: [],
      cars: [],
      incidents: [],
      operation_events: [],
      selected_car_id: nil,
      selected_car_code: nil,
      connection_status: "connecting",
      is_loading: true,
      error: nil
    }
  end

  def component_mounted
    @mounted = true
    subscribe_line_channel
    schedule_line_poll
    schedule_operation_events_poll
  end

  def component_will_unmount
    @mounted = false
    JS.global.clearTimeout(@line_poll_timer_id) if @line_poll_timer_id
    JS.global.clearTimeout(@operation_events_poll_timer_id) if @operation_events_poll_timer_id
    @line_poll_timer_id = nil
    @operation_events_poll_timer_id = nil
    @subscription.unsubscribe if @subscription
    @consumer.disconnect if @consumer
  end

  def render
    render_shell("Line Control") do
      suspense(
        fallback: -> { p(class: "muted") { "Loading line..." } },
        error: ->(error) { p(class: "form-error") { error.to_s } }
      ) do
        div(class: "line-command-bar") do
          div(class: "line-title-block") do
            h3 { value(state.line, :name).to_s }
            span(class: "muted") { "Line ##{props[:id]}" }
          end
          div(class: "line-chip-row") do
            status_chip("Connection", state.connection_status)
            status_chip("Line", value(state.line, :status))
            status_chip("Cars", state.cars.length.to_s)
            status_chip("Open incidents", state.incidents.length.to_s)
          end
        end
        div(class: "control-grid") do
          div(class: "main-column") do
            div(class: "panel map-panel") do
              div(class: "row spread panel-heading") do
                h3 { "Track" }
                span(class: "muted") { selected_car ? "Controlling #{value(selected_car, :name)}" : "No car selected" }
              end
              component(Funicular::ErrorBoundary, fallback: ->(error) {
                component(ErrorPanelComponent, title: "Line map failed", message: error.message)
              }) do
                component(LineMapComponent,
                  line: state.line,
                  stations: state.stations,
                  cars: state.cars,
                  selected_car_id: selected_car_id,
                  on_select: method(:select_car)
                )
              end
            end
            div(class: "panel fleet-panel") do
              div(class: "row spread panel-heading") do
                h3 { "Fleet" }
                span(class: "muted") { "Select one car to command" }
              end
              div(class: "car-grid") do
                state.cars.each do |car|
                  component(CarCardComponent,
                    car: car,
                    selected: object_id(car) == selected_car_id.to_i,
                    on_select: method(:select_car)
                  )
                end
              end
            end
          end
          aside(class: "side-column") do
            component(DispatchConsoleComponent,
              car: selected_car,
              line_id: props[:id],
              on_dispatch: method(:handle_dispatch_response),
              on_error: method(:handle_dispatch_error)
            )
            component(LineStatusPanelComponent,
              line: state.line,
              on_line_updated: method(:handle_line_status_response)
            )
            component(StationPanelComponent,
              line_id: props[:id],
              stations: state.stations,
              on_station_updated: method(:handle_station_response)
            )
          end
        end
        div(class: "line-lower-grid") do
          component(IncidentFormComponent,
            line_id: props[:id],
            stations: state.stations,
            cars: state.cars,
            on_created: method(:handle_incident_created)
          )
          component(Funicular::ErrorBoundary, fallback: ->(error) {
            component(ErrorPanelComponent, title: "Operation log failed", message: error.message)
          }) do
            component(OperationLogComponent, events: state.operation_events, scroll_key: "line-#{props[:id]}")
          end
        end
      end
    end
  end

  def status_chip(label_text, value_text)
    span(class: "status-metric") do
      span(class: "status-metric-label") { label_text }
      span(class: "status-metric-value") { value_text.to_s }
    end
  end

  def subscribe_line_channel
    @consumer = Funicular::Cable.create_consumer(cable_url)
    @subscription = @consumer.subscriptions.create(channel: "LineChannel", line_id: props[:id]) do |message|
      handle_line_message(message)
    end
    @subscription.on_connected do
      patch(connection_status: "connected")
    end
    @subscription.on_rejected do
      patch(connection_status: "rejected")
    end
  end

  def handle_line_message(message)
    type = message["type"]
    if type == "car_position_updated" || type == "operation_event"
      patch_car_payload(message["car"])
      safe_append_operation_event(message["event"])
    elsif type == "incident_created"
      patch(incidents: prepend_unique(state.incidents, message["incident"], 100))
      safe_append_operation_event(message["event"])
    elsif type == "incident_updated"
      patch(incidents: replace_by_id(state.incidents, message["incident"]))
      safe_append_operation_event(message["event"])
    elsif type == "comment_created"
      safe_append_operation_event(message["event"])
    elsif type == "station_updated"
      Funicular::HTTP.expire_cache("/api/lines/#{props[:id]}")
      Funicular::HTTP.expire_cache("/api/lines/#{props[:id]}/stations")
      patch(stations: replace_by_id(state.stations, message["station"]))
      safe_append_operation_event(message["event"])
    elsif type == "line_status_updated"
      Funicular::HTTP.expire_cache("/api/lines")
      Funicular::HTTP.expire_cache("/api/lines/#{props[:id]}")
      patch_line_payload(message["line"])
      safe_append_operation_event(message["event"])
    elsif type == "dispatch_error"
      patch(error: message["errors"].to_s)
    end
  end

  def safe_append_operation_event(event)
    append_operation_event(event)
  rescue => error
    JS.global.console.warn("Operation log update failed", error.to_s) if JS.global[:console]
  end

  def append_operation_event(event)
    return unless event

    next_events = merge_operation_events([ event ])
    OperationLogCache.where(line_id: props[:id].to_s).replace(next_events)
    Funicular::HTTP.expire_cache("/api/lines/#{props[:id]}/operation_events?limit=100")
    Funicular::HTTP.expire_cache("/api/lines/#{props[:id]}/operation_events?limit=200")
    patch(operation_events: next_events)
  end

  def merge_operation_events(events)
    merge_unique_by_id(state.operation_events, events, 100)
  end

  def select_car(car_id)
    car = current_line_cars.find { |item| object_id(item) == car_id.to_i }
    patch(
      selected_car_id: selection_id(car),
      selected_car_code: selection_code(car)
    )
  end

  def selected_car
    selection_candidate(current_line_cars) || state.cars.first
  end

  def selected_car_id
    car = selected_car
    car ? object_id(car) : nil
  end

  def current_line_cars
    line_id = props[:id].to_s
    cars = state.cars.select { |car| value(car, :line_id).to_s == line_id }
    cars.empty? ? state.cars : cars
  end

  def handle_dispatch_response(data)
    patch_car_payload(data["car"])
    safe_append_operation_event(data["event"])
  end

  def handle_dispatch_error(_response)
    Funicular::HTTP.expire_cache("/api/lines/#{props[:id]}")
    reload_line
  end

  def handle_line_status_response(data)
    patch_line_payload(data["line"])
    safe_append_operation_event(data["event"])
  end

  def handle_station_response(data)
    patch(stations: replace_by_id(state.stations, data["station"]))
    safe_append_operation_event(data["event"])
  end

  def handle_incident_created(incident)
    patch(incidents: prepend_unique(state.incidents, incident, 100))
  end

  def patch_line_payload(line_data)
    return unless line_data

    line = line_data
    cars = value(line_data, :cars) || state.cars
    stations = value(line_data, :stations) || state.stations
    selected = selection_candidate(cars)

    patch(
      line: line,
      cars: cars,
      stations: stations,
      selected_car_id: selection_id(selected),
      selected_car_code: selection_code(selected)
    )
  end

  def patch_car_payload(car_data)
    return unless car_data

    next_cars = replace_car_by_id_or_code(state.cars, car_data)
    selected = selection_candidate(next_cars)
    patch(
      cars: next_cars,
      selected_car_id: selection_id(selected),
      selected_car_code: selection_code(selected)
    )
  end

  def replace_car_by_id_or_code(cars, car_data)
    replaced = false
    car_id = object_id(car_data)
    car_code = value(car_data, :code).to_s

    next_cars = cars.map do |car|
      same_id = object_id(car) == car_id
      same_code = !car_code.empty? && value(car, :code).to_s == car_code
      if same_id || same_code
        replaced = true
        car_data
      else
        car
      end
    end

    replaced ? next_cars : [ car_data ] + cars
  end

  def selection_candidate(cars)
    return nil if cars.empty?

    selected_id = state.selected_car_id.to_i
    selected_code = state.selected_car_code.to_s
    cars.find { |car| selected_id > 0 && object_id(car) == selected_id } ||
      cars.find { |car| !selected_code.empty? && value(car, :code).to_s == selected_code } ||
      cars.first
  end

  def selection_id(car)
    car ? object_id(car) : nil
  end

  def selection_code(car)
    car ? value(car, :code).to_s : nil
  end

  def reload_line
    Funicular::HTTP.get("/api/lines/#{props[:id]}?fresh=#{Time.now.to_i}") do |response|
      patch_line_payload(response.data) if response.ok
    end
  end

  def schedule_line_poll
    return unless @mounted

    @line_poll_timer_id = JS.global.setTimeout(1000) do
      poll_line
    end
  end

  def poll_line
    return unless @mounted

    schedule_line_poll
    Funicular::HTTP.get("/api/lines/#{props[:id]}?fresh=#{Time.now.to_i}") do |response|
      patch_line_payload(response.data) if response.ok
    end
  end

  def schedule_operation_events_poll
    return unless @mounted

    @operation_events_poll_timer_id = JS.global.setTimeout(1000) do
      @operation_events_poll_timer_id = nil
      poll_operation_events
    end
  end

  def poll_operation_events
    return unless @mounted

    schedule_operation_events_poll
    Funicular::HTTP.get(operation_events_url) do |response|
      safe_append_operation_events(response.data) if response.ok
    end
  end

  def safe_append_operation_events(events)
    append_operation_events(events)
  rescue => error
    JS.global.console.warn("Operation log refresh failed", error.to_s) if JS.global[:console]
  end

  def append_operation_events(events)
    return unless events
    return unless includes_new_operation_event?(events)

    next_events = merge_operation_events(events)
    OperationLogCache.where(line_id: props[:id].to_s).replace(next_events)
    patch(operation_events: next_events)
  end

  def includes_new_operation_event?(events)
    latest_id = latest_operation_event_id
    events.each do |event|
      return true if object_id(event) > latest_id
    end

    false
  end

  def operation_events_url
    query = "limit=100&fresh=#{Time.now.to_i}"
    after_id = latest_operation_event_id
    query = "#{query}&after_id=#{after_id}" if after_id > 0

    "/api/lines/#{props[:id]}/operation_events?#{query}"
  end

  def latest_operation_event_id
    latest_id = 0
    (state.operation_events || []).each do |event|
      event_id = object_id(event)
      latest_id = event_id if event_id > latest_id
    end
    latest_id
  end
end
