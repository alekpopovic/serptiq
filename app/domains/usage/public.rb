# frozen_string_literal: true

module Usage
  module Public
    QuotaExceeded = Usage::QuotaExceeded
    Conflict = Usage::Conflict
    Invalid = Usage::Invalid
    BillingPeriod = Usage::BillingPeriod
    SourceReference = Usage::SourceReference

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

    def resolve_exact_meter_rate(**attributes)
      ResolveExactMeterRate.new.call(**attributes)
    end

    def resolve_meter_snapshot(**attributes)
      ResolveMeterSnapshot.new.call(**attributes)
    end

    def source_event(**attributes)
      FindSourceEvent.new.call(**attributes)
    end

    def record(**attributes)
      RecordEvent.new.call(**attributes)
    end

    def correct(**attributes)
      RecordCorrection.new.call(**attributes)
    end

    def correct_with_authority(**attributes)
      RecordAuthorizedCorrection.new.call(**attributes)
    end

    def record_manual_adjustment(**attributes)
      RecordManualAdjustment.new.call(**attributes)
    end

    def summary(**attributes)
      AggregateQuery.new.call(**attributes)
    end

    def source_summary(**attributes)
      SourceAggregateQuery.new.call(**attributes)
    end

    def reserve(**attributes)
      ReserveQuota.new.call(**attributes)
    end

    def extend_reservation(**attributes)
      ExtendQuotaReservation.new.call(**attributes)
    end

    def allocate_reservation(clock: -> { Time.current }, **attributes)
      AllocateQuotaReservation.new(clock: clock).call(**attributes)
    end

    def consume_allocation(clock: -> { Time.current }, **attributes)
      CompleteQuotaAllocation.new(clock: clock).call(**attributes, disposition: "consume")
    end

    def release_allocation(clock: -> { Time.current }, **attributes)
      CompleteQuotaAllocation.new(clock: clock).call(**attributes, disposition: "release")
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

    def project_readiness(**attributes)
      ProjectUsageReadinessQuery.new.call(**attributes)
    end

    def reservation_reference(organization_id:, reservation_id:)
      reservation = QuotaReservation.find_by(
        organization_id: organization_id,
        id: reservation_id
      )
      return unless reservation

      ReservationReference.new(
        id: reservation.id,
        organization_id: reservation.organization_id,
        state: reservation.state,
        held_quantity: reservation.held_quantity,
        expires_at: reservation.expires_at
      )
    end
  end
end
