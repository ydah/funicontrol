require "application_system_test_case"
require "timeout"

class TwoBrowserSyncTest < ApplicationSystemTestCase
  test "dispatch updates another browser on the same line" do
    line = create_funicontrol_line
    car = line.cars.first

    using_session(:monitor) do
      visit "/dashboard"
      assert subscribe_to_line(line.id)
    end

    using_session(:operator) do
      visit "/dashboard"
      status = dispatch_car(line, car)
      assert_equal "emergency", status
    end

    using_session(:monitor) do
      assert_received_event("car_emergency_stopped")
    end
  end

  private

  def subscribe_to_line(line_id)
    page.driver.browser.execute_async_script(<<~JAVASCRIPT, line_id)
      const lineId = arguments[0];
      const done = arguments[arguments.length - 1];
      window.receivedLineMessages = [];
      const socket = new WebSocket((location.protocol === "https:" ? "wss://" : "ws://") + location.host + "/cable");
      const identifier = JSON.stringify({ channel: "LineChannel", line_id: lineId });
      socket.onopen = function() {
        socket.send(JSON.stringify({ command: "subscribe", identifier: identifier }));
      };
      socket.onmessage = function(event) {
        const data = JSON.parse(event.data);
        if (data.message) window.receivedLineMessages.push(data.message);
        if (data.type === "confirm_subscription" && data.identifier === identifier) done(true);
      };
      socket.onerror = function() { done(false); };
    JAVASCRIPT
  end

  def dispatch_car(line, car)
    page.driver.browser.execute_async_script(<<~JAVASCRIPT, line.id, car.id, car.code)
      const lineId = arguments[0];
      const carId = arguments[1];
      const code = arguments[2];
      const done = arguments[arguments.length - 1];
      fetch(`/api/lines/${lineId}/dispatch`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          action: "emergency_stop",
          reason: "system sync",
          car_id: carId,
          code: code
        })
      }).then((response) => response.json()).then((data) => done(data.car.status));
    JAVASCRIPT
  end

  def assert_received_event(event_type)
    Timeout.timeout(8) do
      loop do
        seen = page.evaluate_script(<<~JAVASCRIPT)
          (window.receivedLineMessages || []).some(function(message) {
            return message.event && message.event.event_type === #{event_type.to_json};
          });
        JAVASCRIPT
        return if seen

        sleep 0.1
      end
    end
  end
end
