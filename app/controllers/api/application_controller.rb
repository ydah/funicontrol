module Api
  class ApplicationController < ActionController::API
    before_action :disable_browser_cache

    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid
    rescue_from ArgumentError, with: :render_bad_request

    private

    def disable_browser_cache
      response.headers["Cache-Control"] = "no-store"
      response.headers["Pragma"] = "no-cache"
    end

    def render_validation_errors(record, status: :unprocessable_entity)
      render json: {errors: record.errors.to_hash(true)}, status:
    end

    def render_not_found(error)
      render json: {errors: {base: [error.message]}}, status: :not_found
    end

    def render_record_invalid(error)
      render_validation_errors(error.record)
    end

    def render_bad_request(error)
      render json: {errors: {base: [error.message]}}, status: :bad_request
    end

    def nullable_id(value)
      value.presence
    end

    def find_line(value)
      lookup = value.to_s
      if lookup.match?(/\A\d+\z/)
        Line.find(lookup)
      else
        Line.find_by!(slug: lookup)
      end
    end

    def find_car(value, line: nil)
      scope = line ? line.cars : Car.all
      lookup = value.to_s
      return scope.find(lookup) if lookup.match?(/\A\d+\z/)

      car = scope.find_by(code: lookup)
      return car if car

      raise ActiveRecord::RecordNotFound, "Couldn't find Car with 'id or code'=\"#{lookup}\""
    end
  end
end
