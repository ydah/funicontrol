class RandomSimulationEvents
  WEATHER_WEIGHTS = %w[clear clear clear rain fog wind].freeze

  def self.call(line:, random: Random)
    new(line:, random:).call
  end

  def initialize(line:, random:)
    @line = line
    @random = random
  end

  def call
    maybe_change_weather
    maybe_raise_crowding
  end

  private

  attr_reader :line, :random

  def maybe_change_weather
    return unless random.rand < probability("SIM_WEATHER_PROBABILITY", 0.02)

    condition = WEATHER_WEIGHTS.sample(random:)
    SetLineWeather.call(line:, weather_condition: condition, reason: "simulated weather")
  end

  def maybe_raise_crowding
    return unless random.rand < probability("SIM_CROWDING_PROBABILITY", 0.03)

    station = line.stations.sample(random:)
    return unless station

    station.update!(passenger_level: [ station.passenger_level.to_i + random.rand(5..20), 100 ].min)
    return unless station.passenger_level >= 80 && station.status == "normal"

    SetStationStatus.call(station:, action: "mark_crowded", reason: "simulated crowding")
  end

  def probability(env_name, default_value)
    ENV.fetch(env_name, default_value).to_f
  end
end
