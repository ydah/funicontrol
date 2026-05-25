class SimulationTickJob < ApplicationJob
  queue_as :default

  def perform(line_id: nil, continue: false, interval: nil, random_events: false)
    scope = line_id ? Line.where(id: line_id) : Line.all
    scope.find_each do |line|
      AdvanceCarPositions.call(line:)
      RandomSimulationEvents.call(line:) if random_events
    end

    if continue
      self.class.set(wait: interval_seconds(interval).seconds).perform_later(
        line_id:,
        continue: true,
        interval: interval_seconds(interval),
        random_events:
      )
    end
  end

  private

  def interval_seconds(value)
    [value.to_f, 0.2].max
  end
end
