class Car < ApplicationRecord
  STATUSES = %w[idle running slow stopped emergency inspection_required maintenance].freeze
  DIRECTIONS = %w[up down idle].freeze
  OPERATION_MODES = %w[auto manual inspection].freeze
  STALE_AFTER = 10.seconds

  belongs_to :line
  has_many :incidents, dependent: :nullify
  has_many :operation_events, dependent: :nullify

  validates :name, :code, :status, :direction, :operation_mode, presence: true
  validates :code, uniqueness: { scope: :line_id }
  validates :status, inclusion: { in: STATUSES }
  validates :direction, inclusion: { in: DIRECTIONS }
  validates :operation_mode, inclusion: { in: OPERATION_MODES }
  validates :position, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :speed, numericality: { greater_than_or_equal_to: 0 }

  def stale?(now = Time.current)
    last_seen_at.blank? || last_seen_at < STALE_AFTER.ago(now)
  end

  def next_station
    stations = line.stations.to_a
    return stations.first if direction == "idle"

    if direction == "down"
      stations.reverse.find { |station| station.position.to_f < position.to_f } || stations.first
    else
      stations.find { |station| station.position.to_f > position.to_f } || stations.last
    end
  end

  def eta_seconds
    station = next_station
    return nil unless station
    return nil if speed.to_f <= 0

    ((station.position.to_f - position.to_f).abs / speed.to_f).round
  end
end
