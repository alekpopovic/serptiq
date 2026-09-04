# frozen_string_literal: true

require "digest"

module Onboarding
  class StartDraft
    def initialize(clock: -> { Time.current }, id_generator: -> { SecureRandom.uuid },
      release_key_generator: -> { "prj_#{SecureRandom.hex(16)}" }, access: Access.new,
      preview: BuildPlanPreview.new)
      @clock = clock
      @id_generator = id_generator
      @release_key_generator = release_key_generator
      @access = access
      @preview = preview
    end

    def call(actor_membership:, organization_id:)
      @access.authorize!(actor_membership: actor_membership, organization_id: organization_id)
      plan = @preview.call(
        actor_membership: actor_membership, organization_id: organization_id, at: @clock.call
      )
      created = false
      draft = Draft.transaction do
        lock_start!(organization_id, actor_membership.id)
        Draft.active.find_by(
          organization_id: organization_id, actor_membership_id: actor_membership.id
        ) || begin
          created = true
          Draft.create!(
            organization_id: organization_id,
            actor_membership_id: actor_membership.id,
            project_id: @id_generator.call,
            website_property_id: @id_generator.call,
            android_property_id: @id_generator.call,
            ios_property_id: @id_generator.call,
            project_release_key: @release_key_generator.call,
            crawl_max_urls: default_max_urls(plan),
            crawl_max_depth: 5,
            crawl_query_handling: "tracking_only",
            crawl_obey_robots: true,
            crawl_rendering: false
          )
        end
      end
      Instrumentation.started if created
      draft
    end

    private

    def default_max_urls(plan)
      resolution = plan.crawl_max_urls
      return 1 unless resolution.enabled? && resolution.value.is_a?(Integer) && resolution.value.positive?

      [ resolution.value, 500 ].min
    end

    def lock_start!(organization_id, membership_id)
      value = Digest::SHA256.hexdigest("onboarding:#{organization_id}:#{membership_id}").first(16).to_i(16)
      value -= 2**64 if value >= 2**63
      Draft.connection.execute("SELECT pg_advisory_xact_lock(#{value})")
    end
  end
end
