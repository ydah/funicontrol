class DashboardComponent < ApplicationComponent
  use_suspense :lines_payload,
    ->(resolve, reject) {
      Funicular::HTTP.get_cached("/api/lines") do |response|
        response.ok ? resolve.call(response.data) : reject.call(response.error_message)
      end
    },
    on_resolve: ->(lines) {
      patch(is_loading: false, lines: lines)
      if lines && !lines.empty?
        SelectedLineStore.where.value = value(lines.first, :id)
      end
    }

  def initialize_state
    { lines: [], is_loading: true, error: nil }
  end

  def render
    render_shell("Dashboard") do
      suspense(
        fallback: -> { p(class: "muted") { "Loading dashboard..." } },
        error: ->(error) { p(class: "form-error") { error.to_s } }
      ) do
        div(class: "summary-grid") do
          summary_card("Lines", state.lines.length.to_s)
          summary_card("Running Cars", total_running_cars.to_s)
          summary_card("Open Incidents", total_open_incidents.to_s)
        end
        div(class: "line-list") do
          state.lines.each do |line|
            div(class: "line-row") do
              div do
                h3 { value(line, :name).to_s }
                p(class: "muted") { value(line, :description).to_s }
              end
              link_to "/lines/#{value(line, :id)}", navigate: true, class: "button primary" do
                span { "Open line" }
              end
            end
          end
        end
      end
    end
  end

  def summary_card(label_text, value_text)
    div(class: "summary-card") do
      span(class: "summary-label") { label_text }
      span(class: "summary-value") { value_text }
    end
  end

  def total_running_cars
    state.lines.map { |line| value(line, :running_cars_count).to_i }.reduce(0) { |sum, count| sum + count }
  end

  def total_open_incidents
    state.lines.map { |line| value(line, :open_incidents_count).to_i }.reduce(0) { |sum, count| sum + count }
  end
end
