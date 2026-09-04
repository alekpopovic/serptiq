# frozen_string_literal: true

module Shared
  module JobErrors
    # Retryable failures must be explicitly translated into this family by the
    # domain boundary that understands the failed operation.
    class Transient < StandardError; end
    class TransientInfrastructure < Transient; end
    class TransientProvider < Transient; end

    # Terminal failures are intentionally discarded by the shared job policy.
    # Domain jobs may install a more specific handler when terminal state must
    # also be persisted on an aggregate.
    class Terminal < StandardError; end
    class InvalidArguments < Terminal; end
    class QuotaRejected < Terminal; end
    class Canceled < Terminal; end
    class SecurityRejected < Terminal; end
  end
end
