class ApplicationJob < ActiveJob::Base
  class << self
    def runs_on(queue_name)
      Shared::JobTopology.route(self, queue_name)
    end
  end

  runs_on :default

  retry_on Shared::JobErrors::Transient,
    ActiveRecord::Deadlocked,
    ActiveRecord::LockWaitTimeout,
    wait: :polynomially_longer,
    attempts: 5

  discard_on Shared::JobErrors::Terminal, ActiveJob::DeserializationError
end
