# frozen_string_literal: true

module Onboarding
  class DeleteForLifecycle
    def call(organization_id:, project_id:, deletion_workflow_id:)
      authorized = ActiveRecord::Base.connection.select_value(<<~SQL.squish)
        SELECT resource_deletion_stage_authorized(
          #{ActiveRecord::Base.connection.quote(organization_id)},
          #{ActiveRecord::Base.connection.quote(project_id)},
          NULL,
          'aggregate_records'
        )
      SQL
      raise AccessDenied unless ActiveModel::Type::Boolean.new.cast(authorized)

      Draft.where(organization_id: organization_id, project_id: project_id).delete_all
    end
  end
end
