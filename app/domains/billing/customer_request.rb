# frozen_string_literal: true

module Billing
  CustomerRequest = Data.define(:organization_id, :name, :email, :idempotency_key) do
    def initialize(organization_id:, name:, email:, idempotency_key:)
      super(
        organization_id: ValueNormalization.uuid!(organization_id, name: "organization"),
        name: ValueNormalization.string!(name, name: "customer name", maximum: 160),
        email: ValueNormalization.string!(
          email, name: "email", maximum: 320, pattern: ValueNormalization::EMAIL_PATTERN
        ),
        idempotency_key: ValueNormalization.string!(idempotency_key, name: "idempotency key", maximum: 200)
      )
      freeze
    end

    def as_json(*)
      {
        organization_id: organization_id,
        name: ValueNormalization::FILTERED,
        email: ValueNormalization::FILTERED,
        idempotency_key: ValueNormalization::FILTERED
      }.freeze
    end

    def inspect
      ValueNormalization.safe_inspect(self)
    end
  end
end
