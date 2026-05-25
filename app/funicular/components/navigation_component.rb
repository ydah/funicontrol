class NavigationComponent < ApplicationComponent
  def render
    nav(class: "side-nav") do
      link_to "/dashboard", navigate: true, class: nav_class("/dashboard") do
        span { "Dashboard" }
      end
      link_to line_path, navigate: true, class: line_nav_class do
        span { "Line" }
      end
      link_to "/incidents", navigate: true, class: nav_class("/incidents") do
        span { "Incidents" }
      end
      link_to "/replay", navigate: true, class: nav_class("/replay") do
        span { "Replay" }
      end
      link_to "/settings", navigate: true, class: nav_class("/settings") do
        span { "Settings" }
      end
    end
  end

  def nav_class(path)
    current = Funicular.router ? Funicular.router.current_path.to_s : ""
    active = current == path || (path != "/dashboard" && current.start_with?(path))
    active ? "nav-link active" : "nav-link"
  end

  def line_path
    line_id = SelectedLineStore.where.value
    "/lines/#{line_id || 1}"
  end

  def line_nav_class
    current = Funicular.router ? Funicular.router.current_path.to_s : ""
    current.start_with?("/lines/") || current.start_with?("/cars/") ? "nav-link active" : "nav-link"
  end
end
