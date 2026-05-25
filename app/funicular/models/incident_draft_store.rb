class IncidentDraftStore < Funicular::Store::Singleton
  database "funicontrol"
  scope :line_id
  expires_in 86_400
  cleared_on :logout
end
