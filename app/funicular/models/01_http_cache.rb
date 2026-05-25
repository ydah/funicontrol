module Funicular
  module HTTP
    def self.get_cached(url, &block)
      cache = HttpCacheStore.where(cache_key: url.to_s)
      cached = cache.value
      if cached
        block.call(Response.new(200, cached)) if block
        return
      end

      get(url) do |response|
        cache.value = response.data if response.ok
        block.call(response) if block
      end
    end

    def self.expire_cache(url)
      HttpCacheStore.where(cache_key: url.to_s).clear
    end

    def self.write_cache(url, data)
      HttpCacheStore.where(cache_key: url.to_s).value = data
    end
  end
end
