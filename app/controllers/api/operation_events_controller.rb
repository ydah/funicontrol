module Api
  class OperationEventsController < ApplicationController
    def index
      line = find_line(params[:line_id])
      events = line.operation_events
      events = events.where("id > ?", params[:after_id]) if params[:after_id].present?
      events = events.where("id < ?", params[:before_id]) if params[:before_id].present?
      events = events.where("occurred_at >= ?", parsed_since) if params[:since].present?
      events = events.where(event_type: params[:event_type]) if params[:event_type].present?
      events = events.important if ActiveModel::Type::Boolean.new.cast(params[:important])
      events = events.where(car_id: params[:car_id]) if params[:car_id].present?
      events = events.where(station_id: params[:station_id]) if params[:station_id].present?
      events = events.where(incident_id: params[:incident_id]) if params[:incident_id].present?
      events = events.joins(:incident).where(incidents: {severity: params[:severity]}) if params[:severity].present?
      events = ordered(events).limit(limit)

      render json: OperationEventSerializer.render_collection(events)
    end

    private

    def parsed_since
      Time.iso8601(params[:since])
    rescue ArgumentError
      raise ArgumentError, "since must be an ISO 8601 timestamp"
    end

    def ordered(events)
      return events.chronological if params[:order].to_s == "asc"

      events.reverse_chronological
    end

    def limit
      params.fetch(:limit, 100).to_i.clamp(1, 300)
    end
  end
end
