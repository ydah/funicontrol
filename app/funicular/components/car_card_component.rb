class CarCardComponent < ApplicationComponent
  styles do
    card base: "car-card", variants: {
      idle: "car-idle",
      running: "car-running",
      slow: "car-slow",
      stopped: "car-stopped",
      emergency: "car-emergency",
      maintenance: "car-maintenance"
    }
  end

  def render
    car = props[:car]
    status = value(car, :status).to_s
    selected_class = props[:selected] ? " selected" : ""

    div(class: "#{s.card(status.to_sym)}#{selected_class}", onclick: -> { select_car(car) }) do
      div(class: "row spread") do
        h3 { value(car, :name).to_s }
        span(class: "status-chip") { props[:selected] ? "Selected" : status_label(status) }
      end
      div(class: "metric-grid") do
        metric("Position", "#{percent_position(car)}%")
        metric("Direction", value(car, :direction).to_s)
        metric("Speed", value(car, :speed).to_s)
      end
      div(class: "row") do
        button(class: "button compact primary", onclick: -> { select_car(car) }) { props[:selected] ? "In control" : "Control" }
        link_to "/cars/#{object_id(car)}", navigate: true, class: "button compact secondary" do
          span { "Details" }
        end
      end
    end
  end

  def metric(label_text, value_text)
    div(class: "metric") do
      span(class: "metric-label") { label_text }
      span(class: "metric-value") { value_text }
    end
  end

  def select_car(car)
    props[:on_select].call(object_id(car)) if props[:on_select]
  end
end
