class TrackSegment < ApplicationRecord
  KINDS = %w[speed_limit passing_loop].freeze

  belongs_to :line

  validates :name, :kind, :start_position, :end_position, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :start_position, :end_position, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :speed_limit, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :gradient, numericality: true, allow_nil: true
  validate :end_position_after_start_position

  def covers?(position)
    value = position.to_f
    value >= start_position.to_f && value <= end_position.to_f
  end

  private

  def end_position_after_start_position
    return if start_position.blank? || end_position.blank?
    return if end_position.to_f >= start_position.to_f

    errors.add(:end_position, "must be greater than or equal to start position")
  end
end
