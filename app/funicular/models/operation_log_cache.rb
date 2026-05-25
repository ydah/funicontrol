class OperationLogCache < Funicular::Store::Collection
  database "funicontrol"
  scope :line_id
  limit 300
  order :prepend
  key ->(event) { event["id"] }
  expires_in 1_800
  cleared_on :logout
end
