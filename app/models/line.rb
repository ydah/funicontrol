class Line < ApplicationRecord
  STATUSES = %w[normal suspended maintenance].freeze
  WEATHER_CONDITIONS = %w[clear rain fog wind snow].freeze

  has_many :stations, -> { order(:position) }, dependent: :destroy
  has_many :cars, -> { order(:code) }, dependent: :destroy
  has_many :incidents, dependent: :destroy
  has_many :operation_events, dependent: :destroy
  has_many :track_segments, -> { order(:start_position, :end_position) }, dependent: :destroy
  has_many :daily_reports, dependent: :destroy

  validates :name, :slug, :status, :weather_condition, presence: true
  validates :slug, uniqueness: true
  validates :status, inclusion: {in: STATUSES}
  validates :weather_condition, inclusion: {in: WEATHER_CONDITIONS}
  validates :passenger_satisfaction_score, numericality: {only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100}

  def open_critical_incidents_count
    incidents.where(status: %w[open acknowledged], severity: "critical").count
  end
end
