class SetStationStatus
  Result = Data.define(:station, :event)

  ACTIONS = {
    "raise_alert" => [ "alert", "station_alert_raised" ],
    "clear_alert" => [ "normal", "station_alert_cleared" ],
    "mark_crowded" => [ "crowded", "station_crowded" ],
    "close" => [ "closed", "station_closed" ],
    "reopen" => [ "normal", "station_reopened" ]
  }.freeze

  def self.call(station:, action:, reason: nil)
    new(station:, action:, reason:).call
  end

  def initialize(station:, action:, reason: nil)
    @station = station
    @action = action.to_s
    @reason = reason
  end

  def call
    status, event_type = ACTIONS.fetch(@action) { raise ArgumentError, "Unknown station action: #{@action}" }
    validate_reason!

    ActiveRecord::Base.transaction do
      @station.with_lock do
        @station.update!(status:)
        @station.line.update!(
          passenger_satisfaction_score: [ @station.line.passenger_satisfaction_score.to_i - score_penalty, 0 ].max
        )
        event = @station.line.operation_events.create!(
          station: @station,
          event_type:,
          payload: {
            action: @action,
            reason: @reason,
            station_id: @station.id,
            station_name: @station.name,
            station_status: @station.status,
            status: @station.status,
            passenger_level: @station.passenger_level
          },
          occurred_at: Time.current
        )

        Result.new(station: @station, event:)
      end
    end
  end

  private

  def validate_reason!
    return unless @action.in?(%w[raise_alert close])
    return if @reason.to_s.strip.present?

    raise ArgumentError, "Reason is required for station #{@action.tr('_', ' ')}"
  end

  def score_penalty
    return 0 if @action.in?(%w[clear_alert reopen])

    @action == "close" ? 3 : 1
  end
end
