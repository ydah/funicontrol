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
      photo_filename: photo_filename,
      resolved_at: timestamp(record.resolved_at),
      created_at: timestamp(record.created_at),
      updated_at: timestamp(record.updated_at)
    }.tap do |json|
      json[:station] = StationSerializer.render(record.station) if options[:include_station] && record.station
      json[:car] = CarSerializer.render(record.car) if options[:include_car] && record.car
      if options[:include_comments]
        json[:incident_comments] = IncidentCommentSerializer.render_collection(record.incident_comments.order(:created_at, :id))
      end
    end
  end

  private

  def photo_url
    return nil unless record.photo.attached?

    Rails.application.routes.url_helpers.rails_blob_path(record.photo, only_path: true)
  end

  def photo_filename
    record.photo.attached? ? record.photo.filename.to_s : nil
  end
end
