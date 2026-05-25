class OperationLogComponent < ApplicationComponent
  def initialize_state
    { important_only: false, event_type: "" }
  end

  def component_mounted
    bind_scroll_position
  end

  def component_updated
    bind_scroll_position
  end

  def render
    div(class: "panel operation-log") do
      div(class: "row spread") do
        h3 { "Operation Log" }
        span(class: "muted") { event_count_label }
      end
      div(class: "log-filters") do
        label(class: "toggle") do
          input(type: "checkbox", checked: state.important_only, onchange: ->(event) { patch(important_only: event.target[:checked]) })
          span { "Important" }
        end
        select(class: "input compact-input", value: state.event_type, onchange: ->(event) { patch(event_type: event.target[:value]) }) do
          option(value: "") { "All types" }
          event_types.each do |event_type|
            option(value: event_type) { event_type.tr("_", " ") }
          end
        end
      end
      div(class: "log-list", ref: :log_list) do
        if filtered_events.empty?
          p(class: "muted") { "No operation events yet." }
        end
        latest_id = object_id(filtered_events.first)
        filtered_events.each do |event|
          item_class = object_id(event) == latest_id ? "log-item log-item-new" : "log-item"
          div(class: item_class, id: "event-#{value(event, :id)}") do
            span(class: "log-time") { format_time(value(event, :occurred_at)) }
            span(class: "log-type") { event_label(event) }
          end
        end
      end
    end
  end

  def bind_scroll_position
    list = refs[:log_list]
    return unless list
    return unless JS.global[:FunicontrolOperationLog]

    JS.global[:FunicontrolOperationLog].bind(scroll_key, list)
  end

  def scroll_key
    props[:scroll_key] || "operation-log"
  end

  def event_count_label
    count = filtered_events.length
    return "Latest #{count} events" if count >= event_limit

    "#{count} events"
  end

  def event_limit
    (props[:event_limit] || 100).to_i
  end

  def filtered_events
    events = props[:events] || []
    events = events.select { |event| value(event, :important).to_s == "true" } if state.important_only
    events = events.select { |event| value(event, :event_type).to_s == state.event_type.to_s } unless state.event_type.to_s.empty?
    events
  end

  def event_types
    seen = {}
    (props[:events] || []).map { |event| value(event, :event_type).to_s }.select do |event_type|
      next false if event_type.empty? || seen[event_type]

      seen[event_type] = true
    end
  end

  def event_label(event)
    summary = value(event, :summary).to_s
    return summary unless summary.empty?

    value(event, :event_type).to_s.tr("_", " ")
  end
end
