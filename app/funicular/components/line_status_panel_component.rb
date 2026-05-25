class LineStatusPanelComponent < ApplicationComponent
  def initialize_state
    { reason: "", is_saving: false, notice: nil, error: nil }
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
        label(class: "field-label") { "Reason" }
        input(
          class: "input",
          value: state.reason,
          placeholder: "Optional operator note",
          oninput: ->(event) { patch(reason: event.target[:value]) }
        )
      end
      div(class: "row command-row") do
        button(
          class: "button secondary",
          disabled: state.is_saving || status == "suspended",
          onclick: -> { update_line("suspend") }
        ) { state.is_saving ? "..." : "Suspend" }
        button(
          class: "button primary",
          disabled: state.is_saving || status == "normal",
          onclick: -> { update_line("resume") }
        ) { state.is_saving ? "..." : "Resume" }
      end
      p(class: "notice") { state.notice } if state.notice
      p(class: "form-error") { state.error } if state.error
    end
  end

  def update_line(action)
    line_id = object_id(props[:line])
    return unless line_id > 0

    patch(is_saving: true, notice: nil, error: nil)
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
end
