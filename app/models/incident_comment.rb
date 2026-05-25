class IncidentComment < ApplicationRecord
  belongs_to :incident

  validates :author_name, :body, presence: true
end
