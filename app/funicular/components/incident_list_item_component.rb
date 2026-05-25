class IncidentListItemComponent < ApplicationComponent
  styles do
    severity base: "severity-chip", variants: {
      low: "severity-low",
      medium: "severity-medium",
      high: "severity-high",
      critical: "severity-critical"
    }
  end

  def render
    incident = props[:incident]
    severity = value(incident, :severity).to_s
    div(class: "incident-row") do
      div do
        link_to "/incidents/#{value(incident, :id)}", navigate: true, class: "title-link" do
          span { value(incident, :title).to_s }
        end
        p(class: "muted") { "#{value(incident, :kind)} / #{value(incident, :status)}" }
      end
      span(class: s.severity(severity.to_sym)) { severity_label(severity) }
    end
  end
end
