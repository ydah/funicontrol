class OperationLogComponent < ApplicationComponent
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
      div(class: "log-list", ref: :log_list) do
        if (props[:events] || []).empty?
          p(class: "muted") { "No operation events yet." }
        end
        latest_id = object_id((props[:events] || []).first)
        (props[:events] || []).each do |event|
          item_class = object_id(event) == latest_id ? "log-item log-item-new" : "log-item"
          div(class: item_class, id: "event-#{value(event, :id)}") do
            span(class: "log-time") { format_time(value(event, :occurred_at)) }
            span(class: "log-type") { value(event, :event_type).to_s.tr("_", " ") }
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
    count = (props[:events] || []).length
    return "Latest #{count} events" if count >= event_limit

    "#{count} events"
  end

  def event_limit
    (props[:event_limit] || 100).to_i
  end
end
