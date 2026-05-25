class SetLineStatus
  Result = Data.define(:line, :event)

  ACTIONS = {
    "suspend" => [ "suspended", "line_suspended" ],
    "resume" => [ "normal", "line_resumed" ]
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

    ActiveRecord::Base.transaction do
      @line.update!(status:)
      event = @line.operation_events.create!(
        event_type:,
        payload: {
          action: @action,
          reason: @reason,
          line_status: @line.status
        },
        occurred_at: Time.current
      )

      Result.new(line: @line, event:)
    end
  end
end
