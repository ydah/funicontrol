class CarShowComponent < ApplicationComponent
  use_suspense :car_payload,
    ->(resolve, reject) {
      Car.find(props[:id]) do |car, error|
        error ? reject.call(error) : resolve.call(car)
      end
    },
    on_resolve: ->(car) {
      patch(car: car, is_loading: false)
      load_car_events(car)
      subscribe_car_line(value(car, :line_id))
      schedule_operation_events_poll
    }

  def initialize_state
    {
      car: nil,
      operation_events: [],
      connection_status: "connecting",
      is_loading: true,
      error: nil
    }
  end

  def component_mounted
    @mounted = true
  end

  def component_will_unmount
    @mounted = false
    JS.global.clearTimeout(@operation_events_poll_timer_id) if @operation_events_poll_timer_id
    @operation_events_poll_timer_id = nil
    @subscription.unsubscribe if @subscription
    @consumer.disconnect if @consumer
  end

  def render
    render_shell("Car Detail") do
      suspense(
        fallback: -> { p(class: "muted") { "Loading car..." } },
        error: ->(error) { p(class: "form-error") { error.to_s } }
      ) do
        if state.car
          div(class: "detail-grid") do
            div(class: "main-column") do
              div(class: "panel") do
                div(class: "row spread") do
                  h3 { value(state.car, :name).to_s }
                  span(class: "status-chip") { status_label(value(state.car, :status)) }
                end
                div(class: "metric-grid") do
                  metric("Position", "#{percent_position(state.car)}%")
                  metric("Direction", value(state.car, :direction).to_s)
                  metric("Speed", value(state.car, :speed).to_s)
                end
                p(class: "muted") { "Connection: #{state.connection_status}" }
                link_to "/lines/#{value(state.car, :line_id)}", navigate: true, class: "button secondary" do
                  span { "Back to line" }
                end
              end
              component(OperationLogComponent, events: state.operation_events, scroll_key: "car-#{props[:id]}")
            end
            aside(class: "side-column") do
              component(DispatchConsoleComponent,
                car: state.car,
                line_id: value(state.car, :line_id),
                on_dispatch: method(:handle_dispatch_response)
              )
            end
          end
        end
      end
    end
  end

  def metric(label_text, value_text)
    div(class: "metric") do
      span(class: "metric-label") { label_text }
      span(class: "metric-value") { value_text }
    end
  end

  def load_car_events(car)
    Funicular::HTTP.get("/api/lines/#{value(car, :line_id)}/operation_events?limit=100&fresh=#{Time.now.to_i}") do |response|
      if response.ok
        events = response.data.select { |event| value(event, :car_id).to_i == object_id(car) }
        patch(operation_events: events)
      end
    end
  end

  def subscribe_car_line(line_id)
    return unless line_id

    @consumer = Funicular::Cable.create_consumer(cable_url)
    @subscription = @consumer.subscriptions.create(channel: "LineChannel", line_id: line_id) do |message|
      handle_line_message(message)
    end
    @subscription.on_connected { patch(connection_status: "connected") }
    @subscription.on_rejected { patch(connection_status: "rejected") }
  end

  def handle_line_message(message)
    if (message["type"] == "car_position_updated" || message["type"] == "operation_event") &&
       object_id(message["car"]) == object_id(state.car)
      patch(car: Car.new(message["car"]))
      append_operation_event(message["event"])
    end
  end

  def append_operation_event(event)
    patch(operation_events: merge_unique_by_id(state.operation_events, [ event ], 100))
  end

  def handle_dispatch_response(data)
    patch(car: Car.new(data["car"]))
    append_operation_event(data["event"])
  end

  def schedule_operation_events_poll
    return unless @mounted
    return unless state.car

    @operation_events_poll_timer_id = JS.global.setTimeout(1000) do
      poll_operation_events
    end
  end

  def poll_operation_events
    return unless @mounted
    return unless state.car

    Funicular::HTTP.get(operation_events_url) do |response|
      if response.ok && !(response.data || []).empty?
        events = response.data.select { |event| value(event, :car_id).to_i == object_id(state.car) }
        patch(operation_events: merge_unique_by_id(state.operation_events, events, 100)) unless events.empty?
      end
      schedule_operation_events_poll
    end
  end

  def operation_events_url
    line_id = value(state.car, :line_id)
    query = "limit=100&fresh=#{Time.now.to_i}"
    after_id = latest_operation_event_id
    query = "#{query}&after_id=#{after_id}" if after_id > 0

    "/api/lines/#{line_id}/operation_events?#{query}"
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
