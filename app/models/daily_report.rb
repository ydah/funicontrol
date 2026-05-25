class DailyReport < ApplicationRecord
  belongs_to :line

  validates :report_date, presence: true
end
