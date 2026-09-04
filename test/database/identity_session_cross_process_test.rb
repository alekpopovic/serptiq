# frozen_string_literal: true

require "test_helper"

class IdentitySessionCrossProcessTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    Identity::Session.delete_all
    Identity::User.delete_all
  end

  teardown do
    Identity::Session.delete_all
    Identity::User.delete_all
  end

  test "a separately connected process resolves the opaque token from PostgreSQL" do
    user = create_identity_user
    issued = issue_identity_session(user: user)
    reader, writer = IO.pipe

    process_id = fork do
      reader.close
      ActiveRecord::Base.connection_pool.disconnect!
      found = Identity::Public.authenticate_session!(token: issued.token)
      writer.write(found.user_id == user.id ? "resolved" : "mismatch")
    rescue StandardError => error
      writer.write("error:#{error.class.name}")
    ensure
      writer.close
      exit! 0
    end
    writer.close

    result = reader.read
    Process.wait(process_id)

    assert_equal "resolved", result
  ensure
    reader&.close
    writer&.close unless writer&.closed?
  end
end
