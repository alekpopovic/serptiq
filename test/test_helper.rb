ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

Dir[Rails.root.join("test/support/**/*.rb")].sort.each { |path| require path }

module ActiveSupport
  class TestCase
    # Default to deterministic single-process execution. CI or an explicit local
    # run may opt into isolated parallel databases with PARALLEL_WORKERS.
    parallelize(workers: ENV.fetch("PARALLEL_WORKERS", 1).to_i)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    include TestSupport::AuditAndUsageAssertions
    include TestSupport::CryptoHelpers
    include TestSupport::CrawlPolicyHelpers
    include TestSupport::DeterministicHelpers
    include TestSupport::JobAssertions
    include TestSupport::IdentitySessionHelpers
    include TestSupport::TenancyHelpers
    include TestSupport::GoogleOauthHelpers
    include TestSupport::GithubOauthHelpers
    include TestSupport::OnboardingHelpers
    include TestSupport::PermissionAssertions
    include TestSupport::PlanCatalogHelpers
    include TestSupport::ProjectHelpers
    include TestSupport::PropertyHelpers
    include TestSupport::ScopedAuthorizationExamples
    include TestSupport::TenantIsolationAssertions
    include TestSupport::CurrentTenantHelper
    include TestSupport::UsageHelpers
  end
end

class ActionDispatch::IntegrationTest
  include TestSupport::IdentitySessionHelpers
  include TestSupport::TenancyHelpers
  include TestSupport::TenantIsolationAssertions
end
