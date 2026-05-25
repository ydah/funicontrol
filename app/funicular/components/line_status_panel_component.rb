class LineStatusPanelComponent < ApplicationComponent
  def initialize_state
    { reason: "", weather_condition: "clear", pending_action: nil, is_saving: false, notice: nil, error: nil }
  end

  def render
    line = props[:line]
    status = value(line, :status).to_s

    div(class: "panel line-status-panel compact-panel") do
      div(class: "row spread") do
        h3 { "Line Operations" }
        span(class: "status-chip") { status.empty? ? "unknown" : status }
      end
      div(class: "field") do
        label(class: "field-label") { "Weather" }
        select(
          class: "input",
          value: state.weather_condition,
          disabled: props[:disabled],
          onchange: ->(event) { patch(weather_condition: event.target[:value]) }
        ) do
          %w[clear rain fog wind snow].each do |condition|
            option(value: condition) { condition }
          end
        end
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
      div(class: "row command-row") do
        line_button("suspend", "Suspend", status == "suspended")
        line_button("resume", "Resume", status == "normal")
        line_button("enter_maintenance", "Maintenance", status == "maintenance")
        line_button("exit_maintenance", "Exit maint.", status == "normal")
        button(
          class: "button secondary",
          disabled: state.is_saving || props[:disabled],
          onclick: :update_weather
        ) { state.is_saving ? "..." : "Set weather" }
      end
      p(class: "notice") { state.notice } if state.notice
      p(class: "form-error") { state.error } if state.error
    end
  end

  def line_button(action, label_text, inactive)
    confirm = state.pending_action == action
    button(
      class: confirm ? "button primary" : "button secondary",
      disabled: state.is_saving || props[:disabled] || inactive,
      onclick: -> { confirm ? update_line(action) : patch(pending_action: action, notice: nil, error: nil) }
    ) { state.is_saving ? "..." : (confirm ? "Confirm #{label_text}" : label_text) }
  end

  def update_line(action)
    line_id = object_id(props[:line])
    return unless line_id > 0

    unless reason_valid_for?(action)
      patch(error: "Reason is required", notice: nil)
      return
    end

    patch(is_saving: true, notice: nil, error: nil, pending_action: nil)
    Funicular::HTTP.post("/api/lines/#{line_id}/#{action}", { reason: state.reason }) do |response|
      if response.ok
        Funicular::HTTP.expire_cache("/api/lines")
        Funicular::HTTP.expire_cache("/api/lines/#{line_id}")
        props[:on_line_updated].call(response.data) if props[:on_line_updated]
        patch(is_saving: false, notice: "Line #{action} accepted", error: nil)
      else
        patch(is_saving: false, notice: nil, error: response.error_message.to_s)
      end
    end
  end

  def update_weather
    line_id = object_id(props[:line])
    return unless line_id > 0

    patch(is_saving: true, notice: nil, error: nil)
    Funicular::HTTP.post("/api/lines/#{line_id}/weather", { weather_condition: state.weather_condition, reason: state.reason }) do |response|
      if response.ok
        Funicular::HTTP.expire_cache("/api/lines")
        Funicular::HTTP.expire_cache("/api/lines/#{line_id}")
        props[:on_line_updated].call(response.data) if props[:on_line_updated]
        patch(is_saving: false, notice: "Weather updated", error: nil)
      else
        patch(is_saving: false, notice: nil, error: response.error_message.to_s)
      end
    end
  end

  def reason_valid_for?(action)
    return true unless %w[suspend enter_maintenance].include?(action)

    state.reason.to_s.strip.length > 0
  end
end
