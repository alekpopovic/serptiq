class ApplicationJob < ActiveJob::Base
  TRACE_ID_SERIALIZATION_KEY = "searchops_trace_id"

  attr_accessor :observability_trace_id

  class << self
    def runs_on(queue_name)
      Shared::JobTopology.route(self, queue_name)
    end
  end

  runs_on :default

  before_enqueue :capture_observability_trace
  around_perform :with_current_reset
  around_perform :with_observability_context

  retry_on Shared::JobErrors::Transient,
    ActiveRecord::Deadlocked,
    ActiveRecord::LockWaitTimeout,
    wait: :polynomially_longer,
    attempts: 5

  discard_on Shared::JobErrors::Terminal, ActiveJob::DeserializationError

  def serialize
    super.merge(TRACE_ID_SERIALIZATION_KEY => observability_trace_id)
  end

  def deserialize(job_data)
    super
    self.observability_trace_id = job_data[TRACE_ID_SERIALIZATION_KEY]
    self
  end

  private

  def with_current_reset
    Current.reset
    yield
  ensure
    Current.reset
  end

  def capture_observability_trace
    self.observability_trace_id ||= Shared::Observability::Context.trace_id
  end

  def with_observability_context(&block)
    Shared::Observability::JobContext.new.call(self, &block)
  end
end
