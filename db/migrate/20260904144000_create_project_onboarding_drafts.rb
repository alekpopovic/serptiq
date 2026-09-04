# frozen_string_literal: true

class CreateProjectOnboardingDrafts < ActiveRecord::Migration[8.1]
  def change
    create_table :project_onboarding_drafts, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.uuid :actor_membership_id, null: false
      t.uuid :project_id, null: false
      t.uuid :website_property_id, null: false
      t.uuid :android_property_id, null: false
      t.uuid :ios_property_id, null: false
      t.string :project_release_key, limit: 36, null: false
      t.string :state, limit: 24, null: false, default: "draft"
      t.string :current_step, limit: 24, null: false, default: "project"
      t.string :last_completed_step, limit: 24
      t.string :flow_type, limit: 24
      t.string :project_name, limit: 160
      t.citext :project_slug
      t.text :project_description
      t.string :default_locale, limit: 16
      t.string :time_zone, limit: 64
      t.string :website_kind, limit: 32
      t.string :website_display_name, limit: 160
      t.text :website_origin
      t.boolean :add_android, null: false, default: false
      t.string :android_display_name, limit: 160
      t.citext :android_package_name
      t.boolean :add_ios, null: false, default: false
      t.string :ios_display_name, limit: 160
      t.citext :ios_bundle_id
      t.string :ios_team_id, limit: 10
      t.string :verification_method, limit: 32
      t.integer :crawl_max_urls, null: false, default: 500
      t.integer :crawl_max_depth, null: false, default: 5
      t.string :crawl_query_handling, limit: 24, null: false, default: "tracking_only"
      t.boolean :crawl_obey_robots, null: false, default: true
      t.boolean :crawl_rendering, null: false, default: false
      t.datetime :completed_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_foreign_key :project_onboarding_drafts, :organizations, on_delete: :cascade
    add_foreign_key :project_onboarding_drafts, :memberships,
      column: %i[organization_id actor_membership_id],
      primary_key: %i[organization_id id], on_delete: :cascade,
      name: "fk_project_onboarding_drafts_tenant_actor"
    add_index :project_onboarding_drafts, %i[organization_id actor_membership_id], unique: true,
      where: "state = 'draft'", name: "index_project_onboarding_drafts_on_active_actor"
    add_index :project_onboarding_drafts, :project_id, unique: true
    add_index :project_onboarding_drafts, :website_property_id, unique: true
    add_index :project_onboarding_drafts, :android_property_id, unique: true
    add_index :project_onboarding_drafts, :ios_property_id, unique: true
    add_index :project_onboarding_drafts, :project_release_key, unique: true
    add_index :project_onboarding_drafts, %i[organization_id updated_at],
      where: "state = 'draft'", name: "index_project_onboarding_drafts_on_stale"

    add_check_constraint :project_onboarding_drafts,
      "state IN ('draft', 'completed') AND " \
        "((state = 'draft' AND completed_at IS NULL) OR " \
        "(state = 'completed' AND completed_at IS NOT NULL))",
      name: "project_onboarding_drafts_lifecycle"
    add_check_constraint :project_onboarding_drafts,
      "current_step IN ('project', 'product', 'property', 'verification', 'crawl', 'review') AND " \
        "(last_completed_step IS NULL OR " \
        "last_completed_step IN ('project', 'product', 'property', 'verification', 'crawl', 'review'))",
      name: "project_onboarding_drafts_steps"
    add_check_constraint :project_onboarding_drafts,
      "flow_type IS NULL OR flow_type IN ('website_only', 'combined')",
      name: "project_onboarding_drafts_flow_type"
    add_check_constraint :project_onboarding_drafts,
      "website_kind IS NULL OR website_kind IN ('website', 'web_application')",
      name: "project_onboarding_drafts_website_kind"
    add_check_constraint :project_onboarding_drafts,
      "verification_method IS NULL OR " \
        "verification_method IN ('dns_txt', 'html_file', 'meta_tag', 'search_console')",
      name: "project_onboarding_drafts_verification_method"
    add_check_constraint :project_onboarding_drafts,
      "crawl_max_urls BETWEEN 1 AND 200000 AND crawl_max_depth BETWEEN 0 AND 20 AND " \
        "crawl_query_handling IN ('ignore', 'tracking_only', 'all')",
      name: "project_onboarding_drafts_crawl_bounds"
    add_check_constraint :project_onboarding_drafts,
      "project_release_key ~ '^prj_[0-9a-f]{32}$'",
      name: "project_onboarding_drafts_release_key_format"
    add_check_constraint :project_onboarding_drafts,
      completion_shape,
      name: "project_onboarding_drafts_completion_shape"
  end

  private

  def completion_shape
    <<~SQL.squish
      state = 'draft' OR (
        project_name IS NOT NULL AND project_slug IS NOT NULL
        AND default_locale IS NOT NULL AND time_zone IS NOT NULL
        AND flow_type IS NOT NULL AND website_kind IS NOT NULL
        AND website_display_name IS NOT NULL AND website_origin IS NOT NULL
        AND verification_method IS NOT NULL AND current_step = 'review'
        AND (
          (flow_type = 'website_only' AND add_android = FALSE AND add_ios = FALSE
            AND android_display_name IS NULL AND android_package_name IS NULL
            AND ios_display_name IS NULL AND ios_bundle_id IS NULL AND ios_team_id IS NULL)
          OR
          (flow_type = 'combined' AND (add_android = TRUE OR add_ios = TRUE)
            AND ((add_android = TRUE AND android_display_name IS NOT NULL AND android_package_name IS NOT NULL)
              OR (add_android = FALSE AND android_display_name IS NULL AND android_package_name IS NULL))
            AND ((add_ios = TRUE AND ios_display_name IS NOT NULL
              AND ios_bundle_id IS NOT NULL AND ios_team_id IS NOT NULL)
              OR (add_ios = FALSE AND ios_display_name IS NULL
                AND ios_bundle_id IS NULL AND ios_team_id IS NULL)))
        )
      )
    SQL
  end
end
