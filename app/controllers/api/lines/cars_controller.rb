module Api
  module Lines
    class CarsController < ApplicationController
      def index
        line = Line.find(params[:line_id])
        render json: CarSerializer.render_collection(line.cars)
      end
    end
  end
end
