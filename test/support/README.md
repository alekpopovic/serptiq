# Test support boundary

Files in this directory are loaded in sorted order by `test/test_helper.rb` and
must remain deterministic. They may expose assertions, value builders, local
fakes and bounded test servers; they must not load production credentials or
contact external services.

- `DeterministicHelpers` owns the fixed clock and name-derived UUIDs.
- `CryptoHelpers` creates exact-body HMAC headers and verifies that encrypted
  values are not stored as plaintext.
- `CurrentTenantHelper` scopes future `Current` attributes to a block and
  resets them even after an exception.
- `TenantIsolationAssertions` covers boolean policy, lookup-error and request
  denial styles. Every tenant-owned feature must exercise a real foreign ID.
- `ProviderFake` rejects every unscripted operation.
- Job, permission, audit and usage assertions define stable reusable contracts.
- `Network::MaliciousHttpFixture` binds to `127.0.0.1` on an ephemeral port and
  offers bounded hostile responses. It never accepts a caller-selected bind
  address and never follows the private redirect it emits.

Keep business rules in application modules. Support helpers may assert their
observable contract but must not become an alternate implementation.
