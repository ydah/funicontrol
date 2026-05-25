class SetStationStatus
  Result = Data.define(:station, :event)

  ACTIONS = {
    "raise_alert" => [ "alert", "station_alert_raised" ],
    "clear_alert" => [ "normal", "station_alert_cleared" ]
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

    ActiveRecord::Base.transaction do
      @station.update!(status:)
      event = @station.line.operation_events.create!(
        station: @station,
        event_type:,
        payload: {
          action: @action,
          reason: @reason,
          station_name: @station.name,
          station_status: @station.status
        },
        occurred_at: Time.current
      )

      Result.new(station: @station, event:)
    end
  end
end
