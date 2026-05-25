class OperatorPrefsStore < Funicular::Store::Singleton
  database "funicontrol"
  cleared_on :logout
end
