class HttpCacheStore < Funicular::Store::Singleton
  database "funicontrol"
  scope :cache_key
  expires_in 120
  cleared_on :logout
end
