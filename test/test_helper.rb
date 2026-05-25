ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "securerandom"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    def create_funicontrol_line
      suffix = SecureRandom.hex(4)
      line = Line.create!(
        name: "Test Funicular #{suffix}",
        slug: "test-funicular-#{suffix}",
        status: "normal",
        description: "Test line"
      )
      line.stations.create!(name: "Base", position: 0.0, status: "normal", passenger_level: 10)
      line.stations.create!(name: "Mid", position: 0.5, status: "normal", passenger_level: 20)
      line.stations.create!(name: "Peak", position: 1.0, status: "normal", passenger_level: 30)
      line.cars.create!(name: "Car A", code: "car_a", position: 0.2, direction: "up", speed: 0.02, status: "running")
      line.cars.create!(name: "Car B", code: "car_b", position: 0.8, direction: "down", speed: 0.02, status: "running")
      line
    end
  end
end
