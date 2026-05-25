class Incident < ApplicationRecord
  KINDS = %w[lost_item inspection crowding emergency_stop weather other].freeze
  SEVERITIES = %w[low medium high critical].freeze
  STATUSES = %w[open acknowledged resolved].freeze
  DEFAULT_SEVERITY_BY_KIND = {
    "lost_item" => "low",
    "inspection" => "medium",
    "crowding" => "medium",
    "emergency_stop" => "critical",
    "weather" => "high",
    "other" => "medium"
  }.freeze
  ALLOWED_ATTACHMENT_CONTENT_TYPES = %w[
    image/png image/jpeg image/gif image/webp application/pdf text/plain
  ].freeze
  MAX_ATTACHMENT_SIZE = 5.megabytes
  MAX_ATTACHMENTS = 3

  belongs_to :line
  belongs_to :station, optional: true
  belongs_to :car, optional: true
  has_many :incident_comments, dependent: :destroy
  has_many :operation_events, dependent: :nullify
  has_many_attached :attachments
  has_one_attached :photo

  before_validation :default_severity

  validates :kind, :severity, :status, :title, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :severity, inclusion: { in: SEVERITIES }
  validates :status, inclusion: { in: STATUSES }
  validate :attachments_are_safe

  def acknowledge!
    update!(status: "acknowledged") if status == "open"
  end

  def open_seconds(now = Time.current)
    end_time = resolved_at || now
    (end_time - created_at).to_i
  end

  def sla_status(now = Time.current)
    return "resolved" if status == "resolved"

    threshold = severity.in?(%w[critical high]) ? 15.minutes : 60.minutes
    open_seconds(now) > threshold ? "breached" : "ok"
  end

  private

  def default_severity
    self.severity = DEFAULT_SEVERITY_BY_KIND[kind] if severity.blank? && kind.present?
  end

  def attachments_are_safe
    attached_files = attachments.attachments
    errors.add(:attachments, "are limited to #{MAX_ATTACHMENTS} files") if attached_files.length > MAX_ATTACHMENTS

    attached_files.each do |attachment|
      blob = attachment.blob
      next unless blob

      unless blob.content_type.in?(ALLOWED_ATTACHMENT_CONTENT_TYPES)
        errors.add(:attachments, "#{blob.filename} must be an image, PDF, or text inspection file")
      end
      if blob.byte_size > MAX_ATTACHMENT_SIZE
        errors.add(:attachments, "#{blob.filename} must be smaller than #{MAX_ATTACHMENT_SIZE / 1.megabyte} MB")
      end
    end
  end
end
