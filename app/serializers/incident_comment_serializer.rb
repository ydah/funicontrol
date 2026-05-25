class IncidentCommentSerializer < ApplicationSerializer
  def as_json
    {
      id: record.id,
      incident_id: record.incident_id,
      author_name: record.author_name,
      body: record.body,
      created_at: timestamp(record.created_at),
      updated_at: timestamp(record.updated_at)
    }
  end
end
