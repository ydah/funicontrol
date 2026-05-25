module Api
  class SchemasController < ApplicationController
    ATTRIBUTE_SCHEMA = ->(names) { names.index_with { { type: "string", readonly: true } } }

    SCHEMAS = {
      "line" => {
        attributes: ATTRIBUTE_SCHEMA.call(%w[id name slug status description stations cars open_incidents_count running_cars_count recent_events created_at updated_at]),
        endpoints: {
          all: { path: "/api/lines" },
          find: { path: "/api/lines/:id" }
        }
      },
      "station" => {
        attributes: ATTRIBUTE_SCHEMA.call(%w[id line_id name position status passenger_level created_at updated_at]),
        endpoints: {
          all: { path: "/api/stations" },
          find: { path: "/api/stations/:id" }
        }
      },
      "car" => {
        attributes: ATTRIBUTE_SCHEMA.call(%w[id line_id name code position direction speed status last_seen_at created_at updated_at]),
        endpoints: {
          find: { path: "/api/cars/:id" },
          update: { path: "/api/cars/:id" }
        }
      },
      "incident" => {
        attributes: ATTRIBUTE_SCHEMA.call(%w[id line_id station_id car_id kind severity status title description photo_url photo_filename resolved_at station car incident_comments created_at updated_at]),
        endpoints: {
          all: { path: "/api/incidents" },
          find: { path: "/api/incidents/:id" },
          update: { path: "/api/incidents/:id" }
        }
      },
      "incident_comment" => {
        attributes: ATTRIBUTE_SCHEMA.call(%w[id incident_id author_name body created_at updated_at]),
        endpoints: {
          find: { path: "/api/incident_comments/:id" }
        }
      },
      "operation_event" => {
        attributes: ATTRIBUTE_SCHEMA.call(%w[id line_id car_id station_id incident_id event_type payload occurred_at created_at]),
        endpoints: {
          find: { path: "/api/operation_events/:id" }
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
