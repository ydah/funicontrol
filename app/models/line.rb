class Line < ApplicationRecord
  STATUSES = %w[normal suspended maintenance].freeze

  has_many :stations, -> { order(:position) }, dependent: :destroy
  has_many :cars, -> { order(:code) }, dependent: :destroy
  has_many :incidents, dependent: :destroy
  has_many :operation_events, dependent: :destroy

  validates :name, :slug, :status, presence: true
  validates :slug, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
end
