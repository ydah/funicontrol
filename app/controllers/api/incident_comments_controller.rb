module Api
  class IncidentCommentsController < ApplicationController
    def index
      incident = Incident.find(params[:incident_id])
      comments = incident.incident_comments.order(:created_at, :id)
      render json: IncidentCommentSerializer.render_collection(comments)
    end

    def create
      incident = Incident.find(params[:incident_id])
      comment = incident.incident_comments.build(comment_params)

      if comment.save
        acknowledged = false
        if incident.status == "open"
          incident.update!(status: "acknowledged")
          acknowledged = true
        end
        ack_event = acknowledged ? acknowledgement_event(incident) : nil
        event = OperationEvent.create!(
          line: incident.line,
          incident:,
          event_type: "comment_created",
          payload: {
            incident_id: incident.id,
            incident_status: incident.status,
            incident_title: incident.title,
            author_name: comment.author_name
          },
          occurred_at: Time.current
        )
        LineBroadcaster.broadcast_incident_updated(line: incident.line, incident:, event: ack_event) if ack_event
        LineBroadcaster.broadcast_comment_created(line: incident.line, comment:, event:)
        render json: IncidentCommentSerializer.render(comment), status: :created
      else
        render_validation_errors(comment)
      end
    end

    private

    def comment_params
      params.permit(:author_name, :body)
    end

    def acknowledgement_event(incident)
      OperationEvent.create!(
        line: incident.line,
        incident:,
        event_type: "incident_acknowledged",
        payload: {
          incident_id: incident.id,
          incident_status: incident.status,
          status: incident.status,
          severity: incident.severity,
          title: incident.title
        },
        occurred_at: Time.current
      )
    end
  end
end
