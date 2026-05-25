class ApplicationSerializer
  class << self
    def render(record, **options)
      new(record, **options).as_json
    end

    def render_collection(records, **options)
      records.map { |record| render(record, **options) }
    end
  end

  def initialize(record, **options)
    @record = record
    @options = options
  end

  private

  attr_reader :record, :options

  def timestamp(value)
    value&.iso8601
  end

  def decimal(value)
    value&.to_f
  end
end
