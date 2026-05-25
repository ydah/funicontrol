class StationPanelComponent < ApplicationComponent
  def initialize_state
    { reason: "", is_saving: false, notice: nil, error: nil }
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
          placeholder: "Optional alert note",
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
        button(
          class: "button compact secondary",
          disabled: state.is_saving || status == "alert",
          onclick: -> { update_station(station, "raise_alert") }
        ) { "Alert" }
        button(
          class: "button compact",
          disabled: state.is_saving || status == "normal",
          onclick: -> { update_station(station, "clear_alert") }
        ) { "Clear" }
      end
    end
  end

  def update_station(station, action)
    line_id = props[:line_id]
    station_id = object_id(station)
    return unless line_id && station_id > 0

    patch(is_saving: true, notice: nil, error: nil)
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
end
