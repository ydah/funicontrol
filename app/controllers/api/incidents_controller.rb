module Api
  class IncidentsController < ApplicationController
    def index
      scope = params[:line_id] ? Line.find(params[:line_id]).incidents : Incident.all
      incidents = scope.includes(:station, :car).order(created_at: :desc, id: :desc)
      render json: IncidentSerializer.render_collection(incidents, include_station: true, include_car: true)
    end

    def show
      incident = Incident.includes(:station, :car, :incident_comments, :operation_events).find(params[:id])
      render json: IncidentSerializer.render(incident, include_station: true, include_car: true, include_comments: true, include_events: true)
    end

    def create
      line = Line.find(params[:line_id])
      incident = line.incidents.build(incident_params)
      attach_files(incident)

      if incident.save
        event = create_event(incident:, event_type: "incident_created")
        create_notification_event(incident) if incident.severity == "critical"
        LineBroadcaster.broadcast_incident_created(line:, incident:, event:)
        render json: IncidentSerializer.render(incident), status: :created
      else
        render_validation_errors(incident)
      end
    end

    def update
      incident = Incident.find(params[:id])
      attach_files(incident)

      if incident.update(incident_params)
        event = create_event(incident:, event_type: "incident_updated")
        create_notification_event(incident) if incident.severity == "critical"
        LineBroadcaster.broadcast_incident_updated(line: incident.line, incident:, event:)
        render json: IncidentSerializer.render(incident, include_station: true, include_car: true)
      else
        render_validation_errors(incident)
      end
    end

    def acknowledge
      incident = Incident.find(params[:id])

      if incident.update(status: "acknowledged")
        event = create_event(incident:, event_type: "incident_acknowledged")
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

    def attach_files(incident)
      upload_params.each do |upload|
        incident.attachments.attach(upload)
      end
    end

    def upload_params
      uploads = []
      uploads.concat(Array(params[:attachments])) if params[:attachments].present?
      uploads << params[:photo] if params[:photo].present?
      uploads.compact
    end

    def create_event(incident:, event_type:)
      OperationEvent.create!(
        line: incident.line,
        station: incident.station,
        car: incident.car,
        incident:,
        event_type:,
        payload: {
          incident_id: incident.id,
          incident_status: incident.status,
          status: incident.status,
          severity: incident.severity,
          title: incident.title,
          kind: incident.kind,
          station_id: incident.station_id,
          car_id: incident.car_id
        },
        occurred_at: Time.current
      )
    end

    def create_notification_event(incident)
      incident.line.operation_events.create!(
        station: incident.station,
        car: incident.car,
        incident:,
        event_type: "notification_raised",
        payload: {
          incident_id: incident.id,
          title: incident.title,
          severity: incident.severity,
          status: incident.status
        },
        occurred_at: Time.current
      )
    end
  end
end
