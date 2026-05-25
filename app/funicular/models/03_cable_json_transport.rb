module Funicular
  module Cable
    class Consumer
      private

      def handle_message(data)
        message = Funicular::JSONTransport.parse(data)
        type = message["type"]
        identifier = message["identifier"]

        case type
        when "ping"
          nil
        when "welcome"
          nil
        when "confirm_subscription"
          @subscriptions.notify_subscription_confirmed(identifier)
        when "reject_subscription"
          @subscriptions.notify_subscription_rejected(identifier)
        else
          @subscriptions.notify_message(identifier, message["message"])
        end
      end
    end
  end
end
