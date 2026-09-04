# frozen_string_literal: true

module Authorization
  class CatalogSync
    ADVISORY_LOCK_KEY = 2_902_900_001

    def initialize(catalog: Catalog.load, clock: -> { Time.current })
      @catalog = catalog
      @clock = clock
    end

    def call
      result = Permission.transaction do
        lock_catalog!
        now = @clock.call
        changes = sync_permissions(now)
        changes += sync_roles(now)
        changes += sync_grants(now)
        changes += record_revision(now)
        CatalogSyncResult.new(
          checksum: @catalog.checksum,
          permission_count: @catalog.permissions.length,
          role_count: @catalog.roles.length,
          grant_count: @catalog.roles.sum { |role| role.permission_keys.length },
          change_count: changes
        )
      end
      Shared::Public.emit_structured_event(
        "authorization.catalog_synced",
        outcome: "succeeded",
        operation: result.change_count.zero? ? "verified" : "updated"
      )
      result
    end

    private

    def lock_catalog!
      Permission.connection.execute("SELECT pg_advisory_xact_lock(#{ADVISORY_LOCK_KEY})")
    end

    def sync_permissions(now)
      existing = Permission.lock.index_by(&:key)
      reject_missing!(existing.keys - @catalog.permissions.map(&:key))
      @catalog.permissions.sum do |definition|
        attributes = {
          category: definition.category,
          description: definition.description,
          risk_level: definition.risk_level,
          scope: definition.scope,
          active: true,
          catalog_checksum: @catalog.checksum
        }
        persist_catalog_row(Permission, existing[definition.key], { key: definition.key }.merge(attributes), now)
      end
    end

    def sync_roles(now)
      existing = Role.lock.where(system: true).index_by(&:key)
      reject_missing!(existing.keys - @catalog.roles.map(&:key))
      @catalog.roles.sum do |definition|
        attributes = {
          organization_id: nil,
          key: definition.key,
          name: definition.name,
          system: true,
          mutable: false,
          assignable_scopes: definition.assignable_scopes,
          catalog_checksum: @catalog.checksum,
          archived_at: nil
        }
        persist_catalog_row(Role, existing[definition.key], attributes, now)
      end
    end

    def sync_grants(now)
      permissions = Permission.where(key: @catalog.permissions.map(&:key)).index_by(&:key)
      roles = Role.where(system: true, key: @catalog.roles.map(&:key)).index_by(&:key)
      @catalog.roles.sum do |definition|
        role = roles.fetch(definition.key)
        desired_ids = definition.permission_keys.map { |key| permissions.fetch(key).id }
        existing_ids = RolePermission.where(role_id: role.id).pluck(:permission_id)
        removed = RolePermission.where(role_id: role.id, permission_id: existing_ids - desired_ids).delete_all
        missing = desired_ids - existing_ids
        if missing.any?
          RolePermission.insert_all!(missing.map do |permission_id|
            { role_id: role.id, permission_id: permission_id, created_at: now, updated_at: now }
          end)
        end
        removed + missing.length
      end
    end

    def record_revision(now)
      return 0 if CatalogRevision.exists?(checksum: @catalog.checksum)

      CatalogRevision.create!(
        schema_version: @catalog.schema_version,
        checksum: @catalog.checksum,
        source_path: Catalog::SOURCE_PATH,
        permission_count: @catalog.permissions.length,
        role_count: @catalog.roles.length,
        synced_at: now
      )
      1
    end

    def persist_catalog_row(model, record, attributes, now)
      if record.nil?
        model.insert_all!([ attributes.merge(created_at: now, updated_at: now) ])
        return 1
      end

      comparable = attributes.stringify_keys
      current = record.attributes.slice(*comparable.keys)
      return 0 if current == comparable

      model.where(id: record.id).update_all(attributes.merge(updated_at: now))
      1
    end

    def reject_missing!(keys)
      raise CatalogRemovalDenied.new(keys: keys) if keys.any?
    end
  end
end
