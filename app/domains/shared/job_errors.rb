# frozen_string_literal: true

module Shared
  module JobErrors
    # Retryable failures must be explicitly translated into this family by the
    # domain boundary that understands the failed operation.
    class Transient < Shared::Errors::TransientInfrastructureError; end
    class TransientInfrastructure < Transient; end
    class TransientProvider < Transient
      error_category :external_provider
    end

    # Terminal failures are intentionally discarded by the shared job policy.
    # Domain jobs may install a more specific handler when terminal state must
    # also be persisted on an aggregate.
    class Terminal < Shared::Errors::ConflictError; end
    class InvalidArguments < Terminal
      error_category :validation
    end
    class QuotaRejected < Terminal
      error_category :quota
    end
    class Canceled < Terminal; end
    class SecurityRejected < Terminal
      error_category :unsafe_destination
    end
  end
end
