# frozen_string_literal: true

module Administration
  module DeletionContext
    module_function

    def activate(workflow_id)
      id = workflow_id.to_s
      raise ArgumentError, "deletion workflow id is invalid" unless Shared::Public.application_uuid?(id)

      connection.execute("SET LOCAL searchops.deletion_workflow_id = #{connection.quote(id)}")
      yield
    end

    def connection
      ActiveRecord::Base.connection
    end
    private_class_method :connection
  end
end
