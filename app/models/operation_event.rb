class OperationEvent < ApplicationRecord
  EVENT_TYPES = %w[
    car_started car_stopped car_slowed car_emergency_stopped car_recovered
    car_arrived_station car_departed_station car_distance_warning
    car_position_updated incident_created incident_updated incident_resolved
    incident_acknowledged comment_created notification_raised
    station_alert_raised station_alert_cleared station_crowded station_closed station_reopened
    line_suspended line_resumed line_maintenance_started line_maintenance_ended
    line_weather_changed operator_message_sent daily_report_generated
  ].freeze

  IMPORTANT_EVENT_TYPES = (EVENT_TYPES - %w[car_position_updated]).freeze

  belongs_to :line
  belongs_to :car, optional: true
  belongs_to :station, optional: true
  belongs_to :incident, optional: true

  validates :event_type, :occurred_at, presence: true
  validates :event_type, inclusion: { in: EVENT_TYPES }

  scope :chronological, -> { order(occurred_at: :asc, id: :asc) }
  scope :reverse_chronological, -> { order(occurred_at: :desc, id: :desc) }
  scope :important, -> { where(event_type: IMPORTANT_EVENT_TYPES) }

  def important?
    event_type.in?(IMPORTANT_EVENT_TYPES)
  end

  def summary
    case event_type
    when "car_position_updated"
      "#{payload['car_name'] || 'Car'} at #{percentage(payload['position'])}"
    when "car_arrived_station"
      "#{payload['car_name'] || 'Car'} arrived at #{payload['station_name']}"
    when "car_departed_station"
      "#{payload['car_name'] || 'Car'} departed #{payload['station_name']}"
    when "car_distance_warning"
      "Spacing warning: #{payload['distance']}"
    when "incident_created"
      "Incident opened: #{payload['title']}"
    when "incident_acknowledged"
      "Incident acknowledged: #{payload['title']}"
    when "incident_resolved"
      "Incident resolved: #{payload['title']}"
    when "comment_created"
      "Comment by #{payload['author_name']}"
    when "notification_raised"
      "Notification: #{payload['title']}"
    when "line_weather_changed"
      "Weather changed to #{payload['weather_condition']}"
    when "operator_message_sent"
      "#{payload['operator_name'] || 'Operator'}: #{payload['message']}"
    else
      event_type.tr("_", " ")
    end
  end

  private

  def percentage(value)
    "#{(value.to_f * 100).round(1)}%"
  end
end
