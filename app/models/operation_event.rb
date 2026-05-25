class OperationEvent < ApplicationRecord
  EVENT_TYPES = %w[
    car_started car_stopped car_slowed car_emergency_stopped car_recovered
    car_position_updated incident_created incident_updated incident_resolved
    comment_created station_alert_raised station_alert_cleared line_suspended
    line_resumed
  ].freeze

  belongs_to :line
  belongs_to :car, optional: true
  belongs_to :station, optional: true
  belongs_to :incident, optional: true

  validates :event_type, :occurred_at, presence: true
  validates :event_type, inclusion: { in: EVENT_TYPES }
end
