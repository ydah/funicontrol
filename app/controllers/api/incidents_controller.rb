module Api
  class IncidentsController < ApplicationController
    def index
      scope = params[:line_id] ? Line.find(params[:line_id]).incidents : Incident.all
      incidents = scope.includes(:station, :car).order(created_at: :desc, id: :desc)
      render json: IncidentSerializer.render_collection(incidents, include_station: true, include_car: true)
    end

    def show
      incident = Incident.includes(:station, :car, :incident_comments).find(params[:id])
      render json: IncidentSerializer.render(incident, include_station: true, include_car: true, include_comments: true)
    end

    def create
      line = Line.find(params[:line_id])
      incident = line.incidents.build(incident_params)

      if incident.save
        attach_photo(incident)
        event = create_event(incident:, event_type: "incident_created")
        LineBroadcaster.broadcast_incident_created(line:, incident:, event:)
        render json: IncidentSerializer.render(incident), status: :created
      else
        render_validation_errors(incident)
      end
    end

    def update
      incident = Incident.find(params[:id])

      if incident.update(incident_params)
        attach_photo(incident)
        event = create_event(incident:, event_type: "incident_updated")
        LineBroadcaster.broadcast_incident_updated(line: incident.line, incident:, event:)
        render json: IncidentSerializer.render(incident, include_station: true, include_car: true)
      else
        render_validation_errors(incident)
      end
    end

    def resolve
      incident = Incident.find(params[:id])

      if incident.update(status: "resolved", resolved_at: Time.current)
        event = create_event(incident:, event_type: "incident_resolved")
        LineBroadcaster.broadcast_incident_updated(line: incident.line, incident:, event:)
        render json: IncidentSerializer.render(incident, include_station: true, include_car: true)
      else
        render_validation_errors(incident)
      end
    end

    private

    def incident_params
      permitted = params.permit(:station_id, :car_id, :kind, :severity, :status, :title, :description)
      permitted[:station_id] = nullable_id(permitted[:station_id])
      permitted[:car_id] = nullable_id(permitted[:car_id])
      permitted
    end

    def attach_photo(incident)
      return unless params[:photo].present?

      incident.photo.attach(params[:photo])
    end

    def create_event(incident:, event_type:)
      OperationEvent.create!(
        line: incident.line,
        station: incident.station,
        car: incident.car,
        incident:,
        event_type:,
        payload: {
          incident_status: incident.status,
          severity: incident.severity,
          title: incident.title
        },
        occurred_at: Time.current
      )
    end
  end
end
