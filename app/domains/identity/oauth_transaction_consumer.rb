# frozen_string_literal: true

module Identity
  class OauthTransactionConsumer
    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call(state:)
      transaction = find_transaction(state)
      outcome = consume_with_lock(transaction)

      case outcome
      when :consumed then transaction
      when :expired then raise ExpiredOauthTransaction
      when :already_consumed then raise ConsumedOauthTransaction
      else raise InvalidOauthTransaction
      end
    end

    private

    def find_transaction(state)
      digest = SecretDigest.call(state, purpose: "oauth-state")
      OauthTransaction.find_by!(state_digest: digest)
    rescue ArgumentError, ActiveRecord::RecordNotFound
      raise InvalidOauthTransaction
    end

    def consume_with_lock(transaction)
      OauthTransaction.transaction do
        transaction.lock!
        now = @clock.call
        transaction.attempt_count += 1
        transaction.last_attempted_at = now

        outcome = if transaction.consumed_at?
          :already_consumed
        elsif transaction.expires_at <= now
          :expired
        else
          transaction.consumed_at = now
          :consumed
        end
        transaction.save!
        outcome
      end
    end
  end
end
