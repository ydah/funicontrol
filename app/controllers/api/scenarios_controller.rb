module Api
  class ScenariosController < ApplicationController
    def import
      line = find_line(params[:line_id])
      events = ImportScenarioEvents.call(line:, events: params[:events])

      render json: {
        imported_count: events.length,
        events: OperationEventSerializer.render_collection(events)
      }, status: :created
    end
  end
end
