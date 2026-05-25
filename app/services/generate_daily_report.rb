class GenerateDailyReport
  def self.call(line:, report_date: Date.current)
    new(line:, report_date:).call
  end

  def initialize(line:, report_date:)
    @line = line
    @report_date = report_date.to_date
  end

  def call
    report = line.daily_reports.find_or_initialize_by(report_date:)
    report.payload = payload
    report.save!
    record_event(report)
    report
  end

  private

  attr_reader :line, :report_date

  def payload
    {
      line_id: line.id,
      report_date: report_date.iso8601,
      event_counts: events.group(:event_type).count,
      open_incidents: line.incidents.where.not(status: "resolved").count,
      critical_incidents: line.incidents.where(status: %w[open acknowledged], severity: "critical").count,
      stopped_car_minutes: stopped_car_minutes,
      passenger_satisfaction_score: line.passenger_satisfaction_score
    }
  end

  def events
    line.operation_events.where(occurred_at: report_date.all_day)
  end

  def stopped_car_minutes
    events.where(event_type: %w[car_stopped car_emergency_stopped car_arrived_station]).count * 5
  end

  def record_event(report)
    RecordOperationEvent.call(
      line:,
      event_type: "daily_report_generated",
      payload: {
        report_id: report.id,
        report_date: report_date.iso8601
      },
      occurred_at: Time.current
    )
  end
end
