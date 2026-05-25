class DispatchConsoleComponent < ApplicationComponent
  STALE_SELECTION_MESSAGE = "Line data refreshed. Select a car again."

  styles do
    dispatch_button base: "button dispatch", variants: {
      start: "start",
      stop: "stop",
      slow: "slow",
      emergency_stop: "emergency",
      recover: "recover"
    }
  end

  def initialize_state
    { reason: "", is_dispatching: false, notice: nil, error: nil }
  end

  def component_mounted
    clear_stale_selection_error
  end

  def component_updated
    clear_stale_selection_error
  end

  def render
    car = props[:car]
    div(class: "panel dispatch-console primary-command-panel") do
      div(class: "row spread panel-heading") do
        h3 { "Selected Car" }
        span(class: "status-chip") { car ? status_label(value(car, :status)) : "none" }
      end
      if car
        div(class: "selected-car-summary") do
          span(class: "selected-car-name") { value(car, :name).to_s }
          span(class: "muted") { "#{value(car, :code)} / #{percent_position(car)}% / #{value(car, :direction)}" }
        end
        div(class: "field") do
          label(class: "field-label") { "Reason" }
          input(
            class: "input",
            value: state.reason,
            placeholder: "Optional operator note",
            oninput: ->(event) { patch(reason: event.target[:value]) }
          )
        end
        div(class: "dispatch-grid") do
          dispatch_button("start", "Start")
          dispatch_button("stop", "Stop")
          dispatch_button("slow", "Slow")
          dispatch_button("emergency_stop", "Emergency")
          dispatch_button("recover", "Recover")
        end
        p(class: "notice") { state.notice } if state.notice
        p(class: "form-error") { state.error } if state.error
      else
        div(class: "empty-command-state") do
          p(class: "muted") { "No current car selection." }
        end
      end
    end
  end

  def dispatch_button(action, label_text)
    button(
      class: s.dispatch_button(action.to_sym),
      disabled: state.is_dispatching,
      onclick: -> { handle_dispatch(action) }
    ) { state.is_dispatching ? "..." : label_text }
  end

  def handle_dispatch(action)
    car_data = props[:car]
    return unless car_data

    patch(is_dispatching: true, notice: nil, error: nil)
    Car.new(car_data).dispatch(action: action, reason: state.reason, current_line_id: props[:line_id]) do |response|
      if response.ok
        props[:on_dispatch].call(response.data) if props[:on_dispatch]
        patch(is_dispatching: false, notice: "Command accepted", error: nil)
      else
        props[:on_error].call(response) if props[:on_error]
        patch(is_dispatching: false, notice: nil, error: response.error_message.to_s)
      end
    end
  end

  def clear_stale_selection_error
    patch(error: nil) if state.error == STALE_SELECTION_MESSAGE
  end
end
