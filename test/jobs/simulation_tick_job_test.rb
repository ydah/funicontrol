require "test_helper"

class SimulationTickJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper

  test "performs a simulation tick and can schedule the next tick" do
    line = create_funicontrol_line

    assert_enqueued_with(job: SimulationTickJob) do
      assert_difference "OperationEvent.count", 2 do
        SimulationTickJob.perform_now(line_id: line.id, continue: true, interval: 1)
      end
    end
  end
end
