module Api
  class ReportsController < ApplicationController
    def daily
      line = Line.find(params[:line_id])
      report = GenerateDailyReport.call(line:, report_date: report_date)

      render json: {
        id: report.id,
        line_id: report.line_id,
        report_date: report.report_date.iso8601,
        payload: report.payload,
        created_at: report.created_at.iso8601,
        updated_at: report.updated_at.iso8601
      }
    end

    private

    def report_date
      params[:date].present? ? Date.iso8601(params[:date]) : Date.current
    rescue ArgumentError
      raise ArgumentError, "date must be an ISO 8601 date"
    end
  end
end
