# frozen_string_literal: true

class CreateOrganizationSlugAliases < ActiveRecord::Migration[8.1]
  RESERVED_SLUGS = %w[
    account billing invitations members new projects roles security settings switch teams
  ].freeze

  def change
    create_table :organization_slug_aliases, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: { on_delete: :restrict }
      t.citext :slug, null: false

      t.timestamps
    end

    add_index :organization_slug_aliases, :slug, unique: true
    add_index :organization_slug_aliases, %i[organization_id created_at],
      name: "index_organization_slug_aliases_on_org_and_created"
    add_check_constraint :organization_slug_aliases,
      "slug::text ~ '^[a-z0-9](?:[a-z0-9-]{1,61}[a-z0-9])$'",
      name: "organization_slug_aliases_format"
    add_check_constraint :organization_slug_aliases,
      "slug::text NOT IN (#{quoted_reserved_slugs})",
      name: "organization_slug_aliases_not_reserved"
    add_check_constraint :organizations,
      "slug::text NOT IN (#{quoted_reserved_slugs})",
      name: "organizations_slug_not_reserved"
  end

  private

  def quoted_reserved_slugs
    RESERVED_SLUGS.map { |slug| connection.quote(slug) }.join(", ")
  end
end
