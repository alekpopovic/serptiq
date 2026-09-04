# frozen_string_literal: true

module Properties
  module Public
    module_function

    def create_property(clock: -> { Time.current }, **attributes)
      CreateProperty.new(clock: clock).call(**attributes)
    end

    def update_property(clock: -> { Time.current }, **attributes)
      UpdateProperty.new(clock: clock).call(**attributes)
    end

    def transition_property(clock: -> { Time.current }, **attributes)
      TransitionProperty.new(clock: clock).call(**attributes)
    end

    def create_environment(clock: -> { Time.current }, **attributes)
      CreateEnvironment.new(clock: clock).call(**attributes)
    end

    def update_environment(clock: -> { Time.current }, **attributes)
      UpdateEnvironment.new(clock: clock).call(**attributes)
    end

    def transition_environment(clock: -> { Time.current }, **attributes)
      TransitionEnvironment.new(clock: clock).call(**attributes)
    end

    def environment_page(**attributes)
      EnvironmentDirectory.new.page(**attributes)
    end

    def environment_details(**attributes)
      EnvironmentDirectory.new.find(**attributes)
    end

    def apply_verification_summary(**attributes)
      VerificationSummaryProjection.new.call(**attributes)
    end

    def property_page(**attributes)
      PropertyDirectory.new.page(**attributes)
    end

    def property_details(**attributes)
      PropertyDirectory.new.find(**attributes)
    end

    def project_rollup_reader
      ProjectRollupReader.new
    end

    def canonical_origin(origin:)
      CanonicalOrigin.new(origin: origin)
    end

    def reference(organization_id:, project_id:, property_id:)
      property = Property.includes(
        :website_property_config, :android_property_config, :ios_property_config
      ).find_by(id: property_id, project_id: project_id, organization_id: organization_id)
      return unless property&.configuration_record

      PropertyReference.new(
        id: property.id,
        organization_id: property.organization_id,
        project_id: property.project_id,
        kind: property.kind,
        status: property.status,
        verification_status: property.verification_status,
        configuration: property.configuration_record.value
      )
    end

    def environment_reference(organization_id:, project_id:, property_id:, environment_id:)
      environment = Environment.find_by(
        id: environment_id,
        property_id: property_id,
        project_id: project_id,
        organization_id: organization_id
      )
      return unless environment

      EnvironmentReference.new(
        id: environment.id,
        organization_id: environment.organization_id,
        project_id: environment.project_id,
        property_id: environment.property_id,
        key: environment.key,
        kind: environment.kind,
        status: environment.status,
        primary: environment.primary?,
        origin: environment.origin_value
      )
    end
  end
end
