class IncidentSerializer < ApplicationSerializer
  def as_json
    {
      id: record.id,
      line_id: record.line_id,
      station_id: record.station_id,
      car_id: record.car_id,
      kind: record.kind,
      severity: record.severity,
      status: record.status,
      title: record.title,
      description: record.description,
      photo_url: photo_url,
      thumbnail_url: thumbnail_url,
      photo_filename: photo_filename,
      attachments: attachments,
      open_seconds: record.open_seconds,
      sla_status: record.sla_status,
      resolved_at: timestamp(record.resolved_at),
      created_at: timestamp(record.created_at),
      updated_at: timestamp(record.updated_at)
    }.tap do |json|
      json[:station] = StationSerializer.render(record.station) if options[:include_station] && record.station
      json[:car] = CarSerializer.render(record.car) if options[:include_car] && record.car
      if options[:include_comments]
        json[:incident_comments] = IncidentCommentSerializer.render_collection(record.incident_comments.order(:created_at, :id))
      end
      if options[:include_events]
        json[:related_events] = OperationEventSerializer.render_collection(record.operation_events.reverse_chronological.limit(30))
      end
    end
  end

  private

  def photo_url
    first_attachment = primary_attachment
    return nil unless first_attachment

    Rails.application.routes.url_helpers.rails_blob_path(first_attachment, only_path: true)
  end

  def photo_filename
    primary_attachment&.filename&.to_s
  end

  def thumbnail_url
    attachment = active_attachments.find { |candidate| candidate.blob.content_type.to_s.start_with?("image/") }
    return nil unless attachment

    variant = attachment.variant(resize_to_limit: [360, 240])
    Rails.application.routes.url_helpers.rails_representation_path(variant, only_path: true)
  rescue LoadError, StandardError
    photo_url
  end

  def attachments
    active_attachments.map do |attachment|
      blob = attachment.blob
      {
        id: attachment.id,
        filename: blob.filename.to_s,
        content_type: blob.content_type,
        byte_size: blob.byte_size,
        url: Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true),
        thumbnail_url: attachment_thumbnail_url(attachment)
      }
    end
  end

  def attachment_thumbnail_url(attachment)
    return nil unless attachment.blob.content_type.to_s.start_with?("image/")

    Rails.application.routes.url_helpers.rails_representation_path(
      attachment.variant(resize_to_limit: [240, 160]),
      only_path: true
    )
  rescue LoadError, StandardError
    nil
  end

  def primary_attachment
    return record.attachments.first if record.attachments.attached?
    return record.photo if record.photo.attached?

    nil
  end

  def active_attachments
    return record.attachments.attachments if record.attachments.attached?
    return record.photo.attachments if record.photo.attached?

    []
  end
end
