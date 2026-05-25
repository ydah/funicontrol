class HttpCacheStore < Funicular::Store::Singleton
  database "funicontrol"
  scope :cache_key
  expires_in 300
  cleared_on :logout
end
