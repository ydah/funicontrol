class Station < ApplicationRecord
  STATUSES = %w[normal crowded closed alert].freeze

  belongs_to :line
  has_many :incidents, dependent: :nullify
  has_many :operation_events, dependent: :nullify

  validates :name, :status, presence: true
  validates :status, inclusion: {in: STATUSES}
  validates :position, numericality: {greater_than_or_equal_to: 0, less_than_or_equal_to: 1}
  validates :passenger_level, numericality: {only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100}
end
