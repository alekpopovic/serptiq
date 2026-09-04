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

    def property_page(**attributes)
      PropertyDirectory.new.page(**attributes)
    end

    def property_details(**attributes)
      PropertyDirectory.new.find(**attributes)
    end

    def project_rollup_reader
      ProjectRollupReader.new
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
  end
end
