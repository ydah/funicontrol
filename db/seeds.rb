line = Line.find_or_create_by!(slug: "mt-ruby") do |record|
  record.name = "Mt. Ruby Funicular"
  record.status = "normal"
  record.description = "A small funicular line powered by Ruby."
end

[
  [ "麓駅", 0.0, 20 ],
  [ "中腹駅", 0.5, 40 ],
  [ "山頂駅", 1.0, 60 ]
].each do |name, position, passenger_level|
  station = line.stations.find_or_initialize_by(name:)
  station.update!(
    position:,
    status: "normal",
    passenger_level:
  )
end

[
  [ "Car A", "car_a", 0.15, "up" ],
  [ "Car B", "car_b", 0.85, "down" ]
].each do |name, code, position, direction|
  car = line.cars.find_or_initialize_by(code:)
  car.update!(
    name:,
    position:,
    direction:,
    speed: 0.02,
    status: "running",
    last_seen_at: Time.current
  )
end
