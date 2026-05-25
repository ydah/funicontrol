class Car < ApplicationRecord
  STATUSES = %w[idle running slow stopped emergency maintenance].freeze
  DIRECTIONS = %w[up down idle].freeze

  belongs_to :line
  has_many :incidents, dependent: :nullify
  has_many :operation_events, dependent: :nullify

  validates :name, :code, :status, :direction, presence: true
  validates :code, uniqueness: { scope: :line_id }
  validates :status, inclusion: { in: STATUSES }
  validates :direction, inclusion: { in: DIRECTIONS }
  validates :position, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :speed, numericality: { greater_than_or_equal_to: 0 }
end
