module Api
  class OperationEventsController < ApplicationController
    def index
      line = Line.find(params[:line_id])
      events = line.operation_events
      events = events.where("id > ?", params[:after_id]) if params[:after_id].present?
      events = events.where("occurred_at >= ?", Time.iso8601(params[:since])) if params[:since].present?
      events = events.order(occurred_at: :desc, id: :desc).limit(limit)

      render json: OperationEventSerializer.render_collection(events)
    end

    private

    def limit
      [[ params.fetch(:limit, 100).to_i, 1 ].max, 300].min
    end
  end
end
