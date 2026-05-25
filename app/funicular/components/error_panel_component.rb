class ErrorPanelComponent < ApplicationComponent
  def render
    div(class: "error-panel") do
      h3 { props[:title] || "Panel failed" }
      p { props[:message].to_s }
      button(class: "button secondary", onclick: -> { JS.global.location.reload }) { "Reload" }
    end
  end
end
