class ApplicationJob < ActiveJob::Base
  TRACE_ID_SERIALIZATION_KEY = "searchops_trace_id"

  class_attribute :authorization_job_policy,
    instance_accessor: false,
    default: nil

  attr_accessor :observability_trace_id

  class << self
    def runs_on(queue_name)
      Shared::JobTopology.route(self, queue_name)
    end

    def requires_permission(permission_key)
      self.authorization_job_policy = {
        kind: "user",
        permission: permission_key.to_s
      }.freeze
    end

    def system_authorization(name, reason:)
      raise ArgumentError, "system authorization requires a reason" if reason.to_s.blank?

      self.authorization_job_policy = {
        kind: "system",
        name: name.to_s,
        reason: reason.to_s
      }.freeze
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

  def authorize_job!(user_id:, organization_id:, project_id: nil, property_id: nil, resource: nil, &block)
    policy = self.class.authorization_job_policy
    raise "#{self.class.name} must declare requires_permission" unless policy&.fetch(:kind) == "user"

    Authorization::Public.authorize_job!(
      user_id: user_id,
      organization_id: organization_id,
      permission_key: policy.fetch(:permission),
      project_id: project_id,
      property_id: property_id,
      resource: resource,
      &block
    )
  end

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
