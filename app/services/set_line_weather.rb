class SetLineWeather
  Result = Data.define(:line, :event)

  def self.call(line:, weather_condition:, reason: nil)
    new(line:, weather_condition:, reason:).call
  end

  def initialize(line:, weather_condition:, reason: nil)
    @line = line
    @weather_condition = weather_condition.to_s
    @reason = reason
  end

  def call
    raise ArgumentError, "Unknown weather condition: #{@weather_condition}" unless @weather_condition.in?(Line::WEATHER_CONDITIONS)

    @line.with_lock do
      @line.update!(
        weather_condition: @weather_condition,
        passenger_satisfaction_score: next_score
      )
      event = RecordOperationEvent.call(
        line: @line,
        event_type: "line_weather_changed",
        payload: {
          action: "set_weather",
          reason: @reason,
          weather_condition: @line.weather_condition,
          passenger_satisfaction_score: @line.passenger_satisfaction_score
        },
        occurred_at: Time.current
      )

      Result.new(line: @line, event:)
    end
  end

  private

  def next_score
    penalty = (@weather_condition == "clear") ? 0 : 1
    [@line.passenger_satisfaction_score.to_i - penalty, 0].max
  end
end
