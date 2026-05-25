module Funicular
  module JSONTransport
    class << self
      def parse(text)
        JSON.parse(normalize_numbers(text))
      end

      def normalize_numbers(text)
        ensure_normalizer
        JS.global[:FunicontrolJSONNormalizer].stringifyWithNumberStrings(text.to_s).to_s
      end

      private

      def ensure_normalizer
        return if JS.global[:FunicontrolJSONNormalizer]

        script = JS.document.createElement("script")
        script[:textContent] = <<~JAVASCRIPT
          window.FunicontrolJSONNormalizer = {
            stringifyWithNumberStrings(text) {
              return JSON.stringify(JSON.parse(String(text), function(_key, value) {
                return typeof value === "number" ? String(value) : value;
              }));
            }
          };
        JAVASCRIPT
        JS.document.body.appendChild(script)
        JS.document.body.removeChild(script)
      end
    end
  end
end
