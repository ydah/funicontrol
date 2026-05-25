class StationPanelComponent < ApplicationComponent
  def initialize_state
    { reason: "", pending_station_id: nil, pending_action: nil, is_saving: false, notice: nil, error: nil }
  end

  def render
    div(class: "panel station-panel compact-panel") do
      div(class: "row spread") do
        h3 { "Station Alerts" }
        span(class: "muted") { "#{(props[:stations] || []).length} stops" }
      end
      div(class: "field") do
        label(class: "field-label") { "Reason" }
        input(
          class: "input",
          value: state.reason,
          placeholder: "Station note",
          disabled: props[:disabled],
          oninput: ->(event) { patch(reason: event.target[:value]) }
        )
      end
      div(class: "station-list") do
        (props[:stations] || []).each do |station|
          station_row(station)
        end
      end
      p(class: "notice") { state.notice } if state.notice
      p(class: "form-error") { state.error } if state.error
    end
  end

  def station_row(station)
    status = value(station, :status).to_s
    div(class: "station-control-row #{status == "alert" ? "station-control-alert" : ""}") do
      div do
        span(class: "station-name") { value(station, :name).to_s }
        span(class: "muted") { " #{status} / #{value(station, :passenger_level)}%" }
      end
      div(class: "row station-actions") do
        station_button(station, "raise_alert", "Alert", status == "alert")
        station_button(station, "clear_alert", "Clear", status == "normal")
        station_button(station, "mark_crowded", "Crowd", status == "crowded")
        station_button(station, "close", "Close", status == "closed")
        station_button(station, "reopen", "Open", status == "normal")
      end
    end
  end

  def station_button(station, action, label_text, inactive)
    station_id = object_id(station)
    confirm = state.pending_station_id.to_i == station_id && state.pending_action == action
    button(
      class: "button compact #{confirm ? "primary" : "secondary"}",
      disabled: props[:disabled] || state.is_saving || inactive,
      onclick: -> {
        if confirm
          update_station(station, action)
        else
          patch(pending_station_id: station_id, pending_action: action, notice: nil, error: nil)
        end
      }
    ) { confirm ? "Confirm" : label_text }
  end

  def update_station(station, action)
    line_id = props[:line_id]
    station_id = object_id(station)
    return unless line_id && station_id > 0
    unless reason_valid_for?(action)
      patch(error: "Reason is required", notice: nil)
      return
    end

    patch(is_saving: true, notice: nil, error: nil, pending_station_id: nil, pending_action: nil)
    url = "/api/lines/#{line_id}/stations/#{station_id}/#{action}"
    Funicular::HTTP.post(url, { reason: state.reason }) do |response|
      if response.ok
        Funicular::HTTP.expire_cache("/api/lines/#{line_id}")
        Funicular::HTTP.expire_cache("/api/lines/#{line_id}/stations")
        props[:on_station_updated].call(response.data) if props[:on_station_updated]
        patch(is_saving: false, notice: "Station #{action.tr("_", " ")} accepted", error: nil)
      else
        patch(is_saving: false, notice: nil, error: response.error_message.to_s)
      end
    end
  end

  def reason_valid_for?(action)
    return true unless %w[raise_alert close].include?(action)

    state.reason.to_s.strip.length > 0
  end
end
