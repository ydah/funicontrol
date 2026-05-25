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
      render json: { errors: record.errors.to_hash(true) }, status:
    end

    def render_not_found(error)
      render json: { errors: { base: [ error.message ] } }, status: :not_found
    end

    def render_record_invalid(error)
      render_validation_errors(error.record)
    end

    def render_bad_request(error)
      render json: { errors: { base: [ error.message ] } }, status: :bad_request
    end

    def nullable_id(value)
      value.presence
    end
  end
end
