Funicular.configure_forms do |config|
  config[:error_class] = "form-error"
  config[:field_error_class] = "input-error"
end

Funicular.load_schemas({
  Line => "line",
  Station => "station",
  Car => "car",
  Incident => "incident",
  IncidentComment => "incident_comment",
  OperationEvent => "operation_event"
}) do
  Funicular.start(container: "app") do |router|
    router.get("/dashboard", to: DashboardComponent, as: "dashboard")
    router.get("/lines/:id", to: LineShowComponent, as: "line")
    router.get("/cars/:id", to: CarShowComponent, as: "car")
    router.get("/incidents", to: IncidentIndexComponent, as: "incidents")
    router.get("/incidents/:id", to: IncidentShowComponent, as: "incident")
    router.get("/replay", to: ReplayComponent, as: "replay")
    router.get("/settings", to: SettingsComponent, as: "settings")
    router.set_default("/dashboard")
  end
end
