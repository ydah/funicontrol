class IncidentShowComponent < ApplicationComponent
  use_suspense :incident_payload,
    ->(resolve, reject) {
      Funicular::HTTP.get_cached("/api/incidents/#{props[:id]}") do |response|
        response.ok ? resolve.call(Incident.new(response.data)) : reject.call(response.error_message)
      end
    },
    on_resolve: ->(incident) {
      comments = value(incident, :incident_comments) || []
      patch(is_loading: false, incident: incident, comments: comments)
      subscribe_line_channel(value(incident, :line_id))
    }

  def initialize_state
    {
      incident: nil,
      comments: [],
      comment: { author_name: "operator", body: "" },
      errors: {},
      is_loading: true,
      is_saving: false,
      error: nil
    }
  end

  def component_will_unmount
    @subscription.unsubscribe if @subscription
    @consumer.disconnect if @consumer
  end

  def render
    render_shell("Incident Detail") do
      suspense(
        fallback: -> { p(class: "muted") { "Loading incident..." } },
        error: ->(error) { p(class: "form-error") { error.to_s } }
      ) do
        if state.incident
        incident = state.incident
        div(class: "detail-grid") do
          div(class: "panel") do
            div(class: "row spread") do
              h3 { value(incident, :title).to_s }
              span(class: "status-chip") { value(incident, :status).to_s }
            end
            p(class: "muted") { "#{value(incident, :kind)} / #{severity_label(value(incident, :severity))}" }
            p { value(incident, :description).to_s }
            if value(incident, :photo_url)
              img(src: value(incident, :photo_url).to_s, class: "incident-photo")
            end
            button(class: "button primary", onclick: :resolve_incident, disabled: value(incident, :status) == "resolved") { "Resolve" }
          end
          div(class: "panel") do
            h3 { "Comments" }
            component(IncidentCommentListComponent, comments: state.comments)
            form_for(:comment, on_submit: :submit_comment, class: "stack") do |f|
              field_group("Author") { f.text_field(:author_name, class: "input") }
              field_group("Comment") { f.textarea(:body, class: "input textarea", rows: 3) }
              f.submit(state.is_saving ? "Posting..." : "Post comment", class: "button primary", disabled: state.is_saving)
            end
          end
        end
        end
      end
    end
  end

  def field_group(label_text, &block)
    div(class: "field") do
      label(class: "field-label") { label_text }
      block.call
    end
  end

  def subscribe_line_channel(line_id)
    return unless line_id

    @consumer = Funicular::Cable.create_consumer(cable_url)
    @subscription = @consumer.subscriptions.create(channel: "LineChannel", line_id: line_id) do |message|
      if message["type"] == "comment_created" && message["incident_id"].to_i == props[:id].to_i
        patch(comments: prepend_unique(state.comments, message["comment"], 100))
      elsif message["type"] == "incident_updated" && object_id(message["incident"]) == props[:id].to_i
        patch(incident: Incident.new(message["incident"]))
      end
    end
  end

  def resolve_incident
    Funicular::HTTP.post("/api/incidents/#{props[:id]}/resolve") do |response|
      if response.ok
        Funicular::HTTP.expire_cache("/api/incidents")
        Funicular::HTTP.expire_cache("/api/incidents/#{props[:id]}")
        Funicular::HTTP.expire_cache("/api/lines/#{value(state.incident, :line_id)}/incidents")
        patch(incident: Incident.new(response.data))
      end
    end
  end

  def submit_comment(form_data)
    patch(is_saving: true, errors: {})
    Funicular::HTTP.post("/api/incidents/#{props[:id]}/incident_comments", form_data) do |response|
      if response.ok
        Funicular::HTTP.expire_cache("/api/incidents")
        Funicular::HTTP.expire_cache("/api/incidents/#{props[:id]}")
        patch(
          comments: prepend_unique(state.comments, response.data, 100),
          comment: { author_name: value(state.comment, :author_name) || "operator", body: "" },
          is_saving: false
        )
      else
        patch(errors: normalize_errors(response.data["errors"]), is_saving: false)
      end
    end
  end
end
