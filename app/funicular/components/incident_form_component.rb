class IncidentFormComponent < ApplicationComponent
  def initialize_state
    {
      incident: default_incident,
      errors: {},
      is_submitting: false
    }
  end

  def component_mounted
    draft = draft_store.value
    patch(incident: draft) if draft
  end

  def component_updated
    draft_store.value = state.incident
  end

  def render
    div(class: "panel incident-form") do
      h3 { "Quick Incident" }
      div(class: "quick-template-row") do
        incident_template("Lost item", "lost_item", "low", "Lost item reported")
        incident_template("Crowding", "crowding", "medium", "Station crowding")
        incident_template("Vehicle stop", "emergency_stop", "critical", "Vehicle stopped")
        incident_template("Weather", "weather", "high", "Weather restriction")
      end
      form_for(:incident, on_submit: :handle_submit, class: "stack") do |f|
        field_group("Kind") do
          f.select(:kind, [
            [ "lost_item", "Lost item" ],
            [ "inspection", "Inspection" ],
            [ "crowding", "Crowding" ],
            [ "emergency_stop", "Emergency stop" ],
            [ "weather", "Weather" ],
            [ "other", "Other" ]
          ], class: "input")
        end
        field_group("Severity") do
          f.select(:severity, [
            [ "low", "Low" ],
            [ "medium", "Medium" ],
            [ "high", "High" ],
            [ "critical", "Critical" ]
          ], class: "input")
        end
        field_group("Station") do
          choices = [[ "", "Unassigned" ]] + (props[:stations] || []).map { |station| [ value(station, :id).to_s, value(station, :name).to_s ] }
          f.select(:station_id, choices, class: "input")
        end
        field_group("Car") do
          choices = [[ "", "Unassigned" ]] + (props[:cars] || []).map { |car| [ value(car, :id).to_s, value(car, :name).to_s ] }
          f.select(:car_id, choices, class: "input")
        end
        field_group("Title") do
          f.text_field(:title, class: "input")
        end
        field_group("Description") do
          f.textarea(:description, class: "input textarea", rows: 4)
        end
        field_group("Attachment") do
          f.file_field(:photo, accept: "image/*,application/pdf,text/plain", class: "input", onchange: :handle_photo_change)
          p(class: "muted") { "Selected: #{value(state.incident, :photo_name)}" } if value(state.incident, :photo_name)
        end
        f.submit(state.is_submitting ? "Reporting..." : "Report incident", class: "button primary", disabled: state.is_submitting)
      end
    end
  end

  def incident_template(label_text, kind, severity, title)
    button(
      class: "button compact secondary",
      type: "button",
      onclick: -> {
        patch(incident: state.incident.merge(
          kind: kind,
          severity: severity,
          title: title
        ))
      }
    ) { label_text }
  end

  def field_group(label_text, &block)
    div(class: "field") do
      label(class: "field-label") { label_text }
      block.call
    end
  end

  def handle_submit(form_data)
    patch(is_submitting: true, errors: {})
    upload_form(
      :post,
      "/api/lines/#{props[:line_id]}/incidents",
      form_data,
      file_field: "photo",
      file_global_key: photo_global_key
    ) do |response|
      if response["ok"]
        draft_store.delete
        Funicular::HTTP.expire_cache("/api/incidents")
        Funicular::HTTP.expire_cache("/api/lines")
        Funicular::HTTP.expire_cache("/api/lines/#{props[:line_id]}/incidents")
        patch(incident: default_incident, is_submitting: false, errors: {})
        JS.global[photo_global_key.to_sym] = nil
        props[:on_created].call(response["data"]) if props[:on_created]
      else
        patch(is_submitting: false, errors: normalize_errors(response["data"]["errors"]))
      end
    end
  end

  def handle_photo_change(event)
    file = event.target[:files] ? event.target[:files][0] : nil
    if file
      JS.global[photo_global_key.to_sym] = file
      incident = state.incident.merge(photo_name: file[:name].to_s)
      patch(incident: incident)
    else
      JS.global[photo_global_key.to_sym] = nil
      patch(incident: state.incident.merge(photo_name: nil))
    end
  end

  def default_incident
    {
      kind: "inspection",
      severity: "medium",
      title: "",
      description: "",
      station_id: "",
      car_id: "",
      photo_name: nil
    }
  end

  def draft_store
    IncidentDraftStore.where(line_id: props[:line_id].to_s)
  end

  def photo_global_key
    "FunicontrolIncidentPhoto_#{props[:line_id]}"
  end
end
