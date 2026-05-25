class Incident < ApplicationRecord
  KINDS = %w[lost_item inspection crowding emergency_stop weather other].freeze
  SEVERITIES = %w[low medium high critical].freeze
  STATUSES = %w[open acknowledged resolved].freeze

  belongs_to :line
  belongs_to :station, optional: true
  belongs_to :car, optional: true
  has_many :incident_comments, dependent: :destroy
  has_many :operation_events, dependent: :nullify
  has_one_attached :photo

  validates :kind, :severity, :status, :title, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :severity, inclusion: { in: SEVERITIES }
  validates :status, inclusion: { in: STATUSES }
end
