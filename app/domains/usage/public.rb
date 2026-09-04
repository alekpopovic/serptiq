# frozen_string_literal: true

module Usage
  module Public
    QuotaExceeded = Usage::QuotaExceeded

    module_function

    def validate_catalog(path: Catalog::DEFAULT_PATH)
      Catalog.load(path: path)
    end

    def sync_catalog(path: Catalog::DEFAULT_PATH, dry_run: false)
      CatalogSync.new(catalog: validate_catalog(path: path)).call(dry_run: dry_run)
    end

    def resolve_window(**attributes)
      WindowResolver.new.call(**attributes)
    end

    def record(**attributes)
      RecordEvent.new.call(**attributes)
    end

    def correct(**attributes)
      RecordCorrection.new.call(**attributes)
    end

    def record_manual_adjustment(**attributes)
      RecordManualAdjustment.new.call(**attributes)
    end

    def summary(**attributes)
      AggregateQuery.new.call(**attributes)
    end

    def reserve(**attributes)
      ReserveQuota.new.call(**attributes)
    end

    def extend_reservation(**attributes)
      ExtendQuotaReservation.new.call(**attributes)
    end

    def finalize_reservation(**attributes)
      FinalizeQuotaReservation.new.call(**attributes)
    end

    def release_reservation(**attributes)
      ReleaseQuotaReservation.new.call(**attributes)
    end

    def maintain_reservations(**attributes)
      MaintainQuotaReservations.new.call(**attributes)
    end

    def organization_dashboard(**attributes)
      OrganizationUsageQuery.new.call(**attributes)
    end
  end
end
