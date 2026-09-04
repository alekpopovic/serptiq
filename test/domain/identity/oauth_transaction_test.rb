# frozen_string_literal: true

require "test_helper"

class IdentityOauthTransactionTest < ActiveSupport::TestCase
  test "stores only digests and authenticated ciphertext while recovering the PKCE verifier" do
    material = create_oauth_transaction
    transaction = material.fetch(:transaction)
    stored_ciphertext = Identity::OauthTransaction.connection.select_value(
      Identity::OauthTransaction.sanitize_sql_array([
        "SELECT pkce_verifier_ciphertext FROM oauth_transactions WHERE id = ?",
        transaction.id
      ])
    )

    refute_equal material.fetch(:state), transaction.state_digest
    refute_equal material.fetch(:nonce), transaction.nonce_digest
    refute_equal material.fetch(:pkce_verifier), transaction.pkce_verifier_digest
    refute_equal material.fetch(:pkce_verifier), stored_ciphertext
    assert_equal material.fetch(:pkce_verifier), transaction.pkce_verifier
    assert transaction.nonce_matches?(material.fetch(:nonce))
    refute transaction.nonce_matches?("different-#{'n' * 32}")
    refute_includes transaction.inspect, material.fetch(:pkce_verifier)
    refute_includes transaction.attributes.values.map(&:to_s), material.fetch(:state)
    refute_includes Identity::OauthTransaction.column_names, "access_token"
    refute_includes Identity::OauthTransaction.column_names, "refresh_token"
    assert_match Identity::OauthTransaction::DIGEST_PATTERN, transaction.initiator_digest
    refute transaction.link_intent?
    assert_nil transaction.link_session
  end

  test "stores a sanitized allowlisted return path and supports provider flows without nonce" do
    unsafe = create_oauth_transaction(return_to: "https://attacker.example/phish")
    github = create_oauth_transaction(provider: "github", nonce: nil)

    assert_equal "/dashboard", unsafe.fetch(:transaction).return_to
    assert_nil github.fetch(:transaction).nonce_digest

    assert_raises(ActiveRecord::RecordInvalid) do
      create_oauth_transaction(provider: "google", nonce: nil)
    end
  end

  test "consumes once and records every replay attempt" do
    now = Time.current.change(usec: 0)
    material = create_oauth_transaction(expires_at: now + 10.minutes)

    consumed = Identity::Public.consume_oauth_transaction!(state: material.fetch(:state), clock: -> { now })
    assert_equal now, consumed.consumed_at
    assert_equal 1, consumed.attempt_count

    error = assert_raises(Identity::ConsumedOauthTransaction) do
      Identity::Public.consume_oauth_transaction!(state: material.fetch(:state), clock: -> { now + 1.second })
    end
    assert_equal "oauth_transaction_consumed", error.reason_code
    assert_equal 2, consumed.reload.attempt_count
    assert_equal now + 1.second, consumed.last_attempted_at
  end

  test "expired transactions cannot be consumed but retain bounded attempt metadata" do
    expires_at = 5.minutes.from_now
    material = create_oauth_transaction(expires_at: expires_at)

    error = assert_raises(Identity::ExpiredOauthTransaction) do
      Identity::Public.consume_oauth_transaction!(
        state: material.fetch(:state),
        clock: -> { expires_at + 1.second }
      )
    end

    transaction = material.fetch(:transaction).reload
    assert_equal "oauth_transaction_expired", error.reason_code
    assert_nil transaction.consumed_at
    assert_equal 1, transaction.attempt_count
    assert_in_delta expires_at + 1.second, transaction.last_attempted_at, 0.000001
  end

  test "rejects an OAuth transaction lifetime beyond the bounded callback window" do
    error = assert_raises(ActiveRecord::RecordInvalid) do
      create_oauth_transaction(expires_at: 16.minutes.from_now)
    end

    assert_includes error.record.errors[:expires_at], "must be within 15 minutes"
  end

  test "invalid state and corrupted verifier ciphertext produce stable failures without secret text" do
    invalid = assert_raises(Identity::InvalidOauthTransaction) do
      Identity::Public.consume_oauth_transaction!(state: "short")
    end
    assert_equal "oauth_transaction_invalid", invalid.reason_code

    material = create_oauth_transaction
    transaction = material.fetch(:transaction)
    transaction.update_column(:pkce_verifier_ciphertext, "x" * 64)

    corrupt = assert_raises(Identity::CorruptOauthTransaction) { transaction.reload.pkce_verifier }
    assert_equal "oauth_transaction_corrupt", corrupt.reason_code
    refute_includes corrupt.message, material.fetch(:pkce_verifier)
  end

  test "database uniqueness rejects reused state PKCE verifier and session token digests" do
    first = create_oauth_transaction
    duplicate_oauth = first.fetch(:transaction).dup

    oauth_error = assert_raises(ActiveRecord::RecordNotUnique) do
      Identity::OauthTransaction.transaction(requires_new: true) do
        duplicate_oauth.save!(validate: false)
      end
    end
    assert_kind_of PG::UniqueViolation, oauth_error.cause

    issued = issue_identity_session
    duplicate_session = issued.session.dup
    duplicate_session.rotated_from = nil
    session_error = assert_raises(ActiveRecord::RecordNotUnique) do
      Identity::Session.transaction(requires_new: true) do
        duplicate_session.save!(validate: false)
      end
    end
    assert_kind_of PG::UniqueViolation, session_error.cause

    github = create_oauth_transaction(provider: "github", nonce: nil).fetch(:transaction)
    google_without_nonce = github.dup
    google_without_nonce.provider = "google"
    google_without_nonce.state_digest = "a" * 64
    google_without_nonce.pkce_verifier_digest = "b" * 64
    nonce_error = assert_raises(ActiveRecord::StatementInvalid) do
      Identity::OauthTransaction.transaction(requires_new: true) do
        google_without_nonce.save!(validate: false)
      end
    end
    assert_kind_of PG::CheckViolation, nonce_error.cause
  end

  test "model and database require explicit link intent to match its session binding" do
    issued = issue_identity_session
    linked = create_oauth_transaction(link_session: issued.session).fetch(:transaction)

    assert linked.link_intent?
    assert_equal issued.session, linked.link_session

    linked.link_intent = false
    refute linked.valid?
    assert_includes linked.errors[:link_session], "must match explicit link intent"

    database_error = assert_raises(ActiveRecord::StatementInvalid) do
      Identity::OauthTransaction.transaction(requires_new: true) do
        linked.save!(validate: false)
      end
    end
    assert_kind_of PG::CheckViolation, database_error.cause
  ensure
    linked&.reload
  end
end
