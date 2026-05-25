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
    { reason: "", pending_action: nil, is_dispatching: false, notice: nil, error: nil }
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
            placeholder: "Operator note",
            disabled: props[:disabled],
            oninput: ->(event) { patch(reason: event.target[:value]) }
          )
        end
        div(class: "dispatch-grid") do
          dispatch_button("start", "Start")
          dispatch_button("stop", "Stop")
          dispatch_button("slow", "Slow")
          dispatch_button("emergency_stop", "Emergency")
          dispatch_button("recover", recover_label)
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
      disabled: dispatch_disabled?(action),
      onclick: -> {
        if confirm_action?(action)
          handle_dispatch(action)
        else
          patch(pending_action: action, notice: nil, error: nil)
        end
      }
    ) { state.is_dispatching ? "..." : dispatch_label(action, label_text) }
  end

  def handle_dispatch(action)
    car_data = props[:car]
    return unless car_data
    unless reason_valid_for?(action)
      patch(error: "Reason is required", notice: nil)
      return
    end

    patch(is_dispatching: true, notice: nil, error: nil, pending_action: nil)
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

  def dispatch_disabled?(action)
    return true if props[:disabled] || state.is_dispatching
    return true if %w[start slow].include?(action) && props[:line_status].to_s != "normal"

    false
  end

  def confirm_action?(action)
    state.pending_action == action
  end

  def dispatch_label(action, label_text)
    confirm_action?(action) ? "Confirm #{label_text}" : label_text
  end

  def recover_label
    value(props[:car], :status).to_s == "emergency" ? "Inspect" : "Recover"
  end

  def reason_valid_for?(action)
    return true unless action == "emergency_stop"

    state.reason.to_s.strip.length > 0
  end
end
