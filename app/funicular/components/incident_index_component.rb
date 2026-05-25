class IncidentIndexComponent < ApplicationComponent
  def initialize_state
    { incidents: [], is_loading: true, error: nil }
  end

  def component_mounted
    Funicular::HTTP.get_cached("/api/incidents") do |response|
      if response.ok
        incidents = response.data.map { |attrs| Incident.new(attrs) }
        patch(is_loading: false, incidents: incidents)
      else
        patch(is_loading: false, error: response.error_message)
      end
    end
  end

  def render
    render_shell("Incidents") do
      if state.is_loading
        p(class: "muted") { "Loading incidents..." }
      elsif state.error
        p(class: "form-error") { state.error.to_s }
      else
        div(class: "incident-list") do
          if state.incidents.empty?
            p(class: "muted") { "No incidents have been reported." }
          end
          state.incidents.each do |incident|
            component(IncidentListItemComponent, incident: incident)
          end
        end
      end
    end
  end
end
