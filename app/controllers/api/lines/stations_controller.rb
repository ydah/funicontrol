module Api
  module Lines
    class StationsController < ApplicationController
      def index
        line = Line.find(params[:line_id])
        render json: StationSerializer.render_collection(line.stations)
      end

      def raise_alert
        update_status("raise_alert")
      end

      def clear_alert
        update_status("clear_alert")
      end

      def mark_crowded
        update_status("mark_crowded")
      end

      def close
        update_status("close")
      end

      def reopen
        update_status("reopen")
      end

      private

      def update_status(action)
        line = Line.find(params[:line_id])
        station = line.stations.find(params[:id])
        result = SetStationStatus.call(station:, action:, reason: params[:reason])
        LineBroadcaster.broadcast_station_updated(line:, station: result.station, event: result.event)

        render json: {
          station: StationSerializer.render(result.station),
          event: OperationEventSerializer.render(result.event)
        }
      end
    end
  end
end
