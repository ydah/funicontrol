module Api
  module Lines
    class CarsController < ApplicationController
      def index
        line = find_line(params[:line_id])
        render json: CarSerializer.render_collection(line.cars)
      end
    end
  end
end
