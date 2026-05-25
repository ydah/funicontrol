class ReplayComponent < ApplicationComponent
  def render
    render_shell("Replay") do
      component(Funicular::ErrorBoundary, fallback: ->(error) {
        component(ErrorPanelComponent, title: "Replay failed", message: error.message)
      }) do
        component(ReplayPanelComponent)
      end
    end
  end
end
