line = Line.find_or_create_by!(slug: "mt-ruby") do |record|
  record.name = "Mt. Ruby Funicular"
  record.status = "normal"
  record.weather_condition = "clear"
  record.passenger_satisfaction_score = 100
  record.description = "A small funicular line powered by Ruby."
end
line.update!(weather_condition: "clear", passenger_satisfaction_score: 100)

[
  ["麓駅", 0.0, 20],
  ["中腹駅", 0.5, 40],
  ["山頂駅", 1.0, 60]
].each do |name, position, passenger_level|
  station = line.stations.find_or_initialize_by(name:)
  station.update!(
    position:,
    status: "normal",
    passenger_level:
  )
end

[
  ["Passing loop", "passing_loop", 0.47, 0.53, 0.012, 8.0],
  ["Summit approach", "speed_limit", 0.82, 1.0, 0.01, 12.0]
].each do |name, kind, start_position, end_position, speed_limit, gradient|
  segment = line.track_segments.find_or_initialize_by(name:)
  segment.update!(
    kind:,
    start_position:,
    end_position:,
    speed_limit:,
    gradient:
  )
end

[
  ["Car A", "car_a", 0.15, "up"],
  ["Car B", "car_b", 0.85, "down"]
].each do |name, code, position, direction|
  car = line.cars.find_or_initialize_by(code:)
  car.update!(
    name:,
    position:,
    direction:,
    speed: 0.02,
    status: "running",
    operation_mode: "auto",
    dwell_until: nil,
    last_seen_at: Time.current
  )
end

{
  "crowded" => {
    name: "Crowded Demo",
    stations: [["Base", 0.0, 85], ["Mid", 0.5, 70], ["Peak", 1.0, 55]],
    cars: [["Crowd Car A", "crowd_a", 0.12, "up"], ["Crowd Car B", "crowd_b", 0.88, "down"]]
  },
  "emergency" => {
    name: "Emergency Drill",
    stations: [["Depot", 0.0, 20], ["Crossing", 0.5, 35], ["Summit", 1.0, 40]],
    cars: [["Drill Car A", "drill_a", 0.48, "idle", "emergency"], ["Drill Car B", "drill_b", 0.82, "down", "slow"]]
  },
  "maintenance" => {
    name: "Maintenance Window",
    status: "maintenance",
    stations: [["Yard", 0.0, 5], ["Switchback", 0.5, 10], ["Lookout", 1.0, 5]],
    cars: [["Maint Car A", "maint_a", 0.0, "idle", "maintenance"], ["Maint Car B", "maint_b", 1.0, "idle", "stopped"]]
  }
}.each do |slug, scenario|
  scenario_line = Line.find_or_create_by!(slug: "mt-ruby-#{slug}") do |record|
    record.name = scenario.fetch(:name)
    record.status = scenario.fetch(:status, "normal")
    record.weather_condition = (slug == "emergency") ? "wind" : "clear"
    record.passenger_satisfaction_score = (slug == "crowded") ? 72 : 90
    record.description = "Scenario seed for #{slug} operations."
  end
  scenario_line.update!(
    name: scenario.fetch(:name),
    status: scenario.fetch(:status, "normal"),
    weather_condition: (slug == "emergency") ? "wind" : "clear",
    passenger_satisfaction_score: (slug == "crowded") ? 72 : 90
  )

  scenario.fetch(:stations).each do |name, position, passenger_level|
    station = scenario_line.stations.find_or_initialize_by(name:)
    station.update!(position:, status: (passenger_level >= 80) ? "crowded" : "normal", passenger_level:)
  end

  scenario.fetch(:cars).each do |name, code, position, direction, status|
    car = scenario_line.cars.find_or_initialize_by(code:)
    car.update!(
      name:,
      position:,
      direction:,
      speed: (status == "slow") ? 0.008 : 0.02,
      status: status || "running",
      operation_mode: (status == "maintenance") ? "inspection" : "auto",
      dwell_until: nil,
      last_seen_at: Time.current
    )
  end

  segment = scenario_line.track_segments.find_or_initialize_by(name: "Passing loop")
  segment.update!(kind: "passing_loop", start_position: 0.47, end_position: 0.53, speed_limit: 0.012, gradient: 8.0)
end
