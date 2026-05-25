module Api
  class SchemasController < ApplicationController
    ATTRIBUTE_SCHEMA = ->(names) { names.index_with { {type: "string", readonly: true} } }

    SCHEMAS = {
      "line" => {
        attributes: ATTRIBUTE_SCHEMA.call(%w[id name slug status weather_condition passenger_satisfaction_score description stations cars track_segments open_incidents_count running_cars_count critical_incidents_count sla_breached_incidents_count recent_events created_at updated_at]),
        endpoints: {
          all: {path: "/api/lines"},
          find: {path: "/api/lines/:id"},
          suspend: {path: "/api/lines/:id/suspend"},
          resume: {path: "/api/lines/:id/resume"},
          enter_maintenance: {path: "/api/lines/:id/enter_maintenance"},
          exit_maintenance: {path: "/api/lines/:id/exit_maintenance"},
          weather: {path: "/api/lines/:id/weather"}
        }
      },
      "station" => {
        attributes: ATTRIBUTE_SCHEMA.call(%w[id line_id name position status passenger_level created_at updated_at]),
        endpoints: {
          all: {path: "/api/lines/:line_id/stations"},
          raise_alert: {path: "/api/lines/:line_id/stations/:id/raise_alert"},
          clear_alert: {path: "/api/lines/:line_id/stations/:id/clear_alert"},
          mark_crowded: {path: "/api/lines/:line_id/stations/:id/mark_crowded"},
          close: {path: "/api/lines/:line_id/stations/:id/close"},
          reopen: {path: "/api/lines/:line_id/stations/:id/reopen"}
        }
      },
      "car" => {
        attributes: ATTRIBUTE_SCHEMA.call(%w[id line_id name code position direction speed status operation_mode dwell_until stale next_station eta_seconds last_seen_at created_at updated_at]),
        endpoints: {
          find: {path: "/api/cars/:id"},
          dispatch: {path: "/api/cars/:id/dispatch"},
          line_dispatch: {path: "/api/lines/:id/dispatch"}
        }
      },
      "incident" => {
        attributes: ATTRIBUTE_SCHEMA.call(%w[id line_id station_id car_id kind severity status title description photo_url thumbnail_url photo_filename attachments open_seconds sla_status resolved_at station car incident_comments related_events created_at updated_at]),
        endpoints: {
          all: {path: "/api/incidents"},
          line_all: {path: "/api/lines/:line_id/incidents"},
          create: {path: "/api/lines/:line_id/incidents"},
          find: {path: "/api/incidents/:id"},
          update: {path: "/api/incidents/:id"},
          acknowledge: {path: "/api/incidents/:id/acknowledge"},
          resolve: {path: "/api/incidents/:id/resolve"},
          purge_attachment: {path: "/api/incidents/:id/attachments/:attachment_id"}
        }
      },
      "incident_comment" => {
        attributes: ATTRIBUTE_SCHEMA.call(%w[id incident_id author_name body created_at updated_at]),
        endpoints: {
          all: {path: "/api/incidents/:incident_id/incident_comments"},
          create: {path: "/api/incidents/:incident_id/incident_comments"}
        }
      },
      "operation_event" => {
        attributes: ATTRIBUTE_SCHEMA.call(%w[id line_id car_id station_id incident_id event_type payload summary important occurred_at created_at]),
        endpoints: {
          all: {path: "/api/lines/:line_id/operation_events"}
        }
      },
      "track_segment" => {
        attributes: ATTRIBUTE_SCHEMA.call(%w[id line_id name kind start_position end_position speed_limit gradient created_at updated_at]),
        endpoints: {
          all_with_line: {path: "/api/lines/:id"}
        }
      }
    }.with_indifferent_access.freeze

    def show
      schema = SCHEMAS[params[:id]]
      raise ActiveRecord::RecordNotFound, "Schema not found: #{params[:id]}" unless schema

      render json: schema
    end
  end
end
