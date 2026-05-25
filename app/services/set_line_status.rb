class SetLineStatus
  Result = Data.define(:line, :event)

  ACTIONS = {
    "suspend" => ["suspended", "line_suspended"],
    "resume" => ["normal", "line_resumed"],
    "enter_maintenance" => ["maintenance", "line_maintenance_started"],
    "exit_maintenance" => ["normal", "line_maintenance_ended"]
  }.freeze

  def self.call(line:, action:, reason: nil)
    new(line:, action:, reason:).call
  end

  def initialize(line:, action:, reason: nil)
    @line = line
    @action = action.to_s
    @reason = reason
  end

  def call
    status, event_type = ACTIONS.fetch(@action) { raise ArgumentError, "Unknown line action: #{@action}" }
    validate_reason!

    ActiveRecord::Base.transaction do
      @line.with_lock do
        @line.update!(status:, passenger_satisfaction_score: next_score(status))
        event = RecordOperationEvent.call(
          line: @line,
          event_type:,
          payload: {
            action: @action,
            reason: @reason,
            line_status: @line.status,
            status: @line.status,
            weather_condition: @line.weather_condition,
            passenger_satisfaction_score: @line.passenger_satisfaction_score
          },
          occurred_at: Time.current
        )

        Result.new(line: @line, event:)
      end
    end
  end

  private

  def validate_reason!
    return unless @action.in?(%w[suspend enter_maintenance])
    return if @reason.to_s.strip.present?

    raise ArgumentError, "Reason is required for line #{@action.tr("_", " ")}"
  end

  def next_score(status)
    penalty = (status == "normal") ? 0 : 2
    [@line.passenger_satisfaction_score.to_i - penalty, 0].max
  end
end
