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
        event = OperationEvent.create!(
          line: incident.line,
          incident:,
          event_type: "comment_created",
          payload: {
            incident_title: incident.title,
            author_name: comment.author_name
          },
          occurred_at: Time.current
        )
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
  end
end
