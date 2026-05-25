module Funicular
  module HTTP
    class << self
      private

      def request(method, url, body, &block)
        options = { method: method, credentials: "include" }
        headers = {}

        if body
          headers["Content-Type"] = "application/json"
          options[:body] = JSON.generate(body)
        end

        if method != "GET"
          token = csrf_token
          headers["X-CSRF-Token"] = token if token
        end

        options[:headers] = headers unless headers.empty?

        JS.global.fetch(url, options) do |response|
          status = response.status.to_i
          json_text = response.to_binary.to_s
          data = json_text.empty? ? nil : Funicular::JSONTransport.parse(json_text)
          http_response = Response.new(status, data)
          block.call(http_response) if block
        end
      end
    end
  end
end
