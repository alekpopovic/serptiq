# frozen_string_literal: true

require "test_helper"

class BillingSupportRequestTest < ActionDispatch::IntegrationTest
  class RecordingReplayer
    attr_reader :calls

    def initialize
      @calls = []
    end

    def call(**attributes)
      calls << attributes
    end
  end

  class RecordingRequester
    attr_reader :calls

    def initialize(result:)
      @result = result
      @calls = []
    end

    def call(**attributes)
      calls << attributes
      @result
    end
  end

  setup do
    @now = Time.current
    @user = create_identity_user(display_name: "Billing Support Operator")
    @session = issue_identity_session(user: @user, at: @now)
    @previous_replayer = Billing::SupportController.replayer_builder
    @previous_reconciliation = Billing::SupportController.reconciliation_builder
  end

  teardown do
    Billing::SupportController.replayer_builder = @previous_replayer
    Billing::SupportController.reconciliation_builder = @previous_reconciliation
  end

  test "authentication and a platform grant are required independently of organization ownership" do
    get admin_billing_support_path
    assert_response :found

    create_organization_for(user: @user, name: "Owner Not Support", slug: "owner-not-support")
    authenticate_request(@session)
    get admin_billing_support_path
    assert_response :forbidden

    post replay_admin_billing_event_path(SecureRandom.uuid), params: { confirmation: "REPLAY anything" }
    assert_response :forbidden
  end

  test "read grant shows sanitized evidence without mutation controls" do
    grant("billing_support.read")
    event = dead_letter_event
    authenticate_request(@session)

    get admin_billing_support_path

    assert_response :success
    assert_select "h1", text: "Billing support"
    assert_select "td", text: /dead_letter/
    assert_select "form[action='#{replay_admin_billing_event_path(event.id)}']", count: 0
    assert_select "button", text: "Replay", count: 0
    refute_includes response.body, event.provider_event_id
  end

  test "support mutations require manage grant and recent authentication" do
    grant("billing_support.manage")
    stale = issue_identity_session(user: @user, at: 20.minutes.ago)
    recorder = RecordingReplayer.new
    Billing::SupportController.replayer_builder = -> { recorder }
    authenticate_request(stale)

    post replay_admin_billing_event_path(SecureRandom.uuid), params: { confirmation: "REPLAY anything" }

    assert_response :unauthorized
    assert_empty recorder.calls
  end

  test "authorized replay requires exact confirmation and audits the support actor" do
    grant("billing_support.manage")
    event = dead_letter_event
    Billing::SupportController.replayer_builder = -> {
      Billing::ReplayWebhookEvent.new(auditor: Auditing::Public, clock: -> { @now }, enqueue: ->(_id) { })
    }
    authenticate_request(@session)

    post replay_admin_billing_event_path(event.id), params: { confirmation: event.id }
    assert_response :conflict
    assert_equal "dead_letter", event.reload.state

    post replay_admin_billing_event_path(event.id), params: { confirmation: "REPLAY #{event.id}" }

    assert_response :see_other
    assert_equal "pending", event.reload.state
    audit = Auditing::AuditEvent.find_by!(action: "billing.webhook_replayed", target_id: event.id)
    assert_equal @user.id, audit.actor_user_id
  end

  test "authorized targeted reconciliation passes the exact tenant subscription pair" do
    grant("billing_support.manage")
    organization_id = SecureRandom.uuid
    subscription_id = SecureRandom.uuid
    result = Billing::ReconciliationSummary.new(
      id: SecureRandom.uuid,
      organization_id: organization_id,
      subscription_id: subscription_id,
      provider: "fake",
      environment: "test",
      source: "targeted",
      state: "queued",
      difference_fields: [],
      failure_category: nil,
      requested_at: @now,
      completed_at: nil,
      next_attempt_at: nil,
      attempt_count: 0
    )
    requester = RecordingRequester.new(result: result)
    Billing::SupportController.reconciliation_builder = -> { requester }
    authenticate_request(@session)

    post reconcile_admin_billing_subscription_path(subscription_id), params: { organization_id: organization_id }

    assert_response :see_other
    assert_equal 1, requester.calls.length
    call = requester.calls.sole
    assert_equal [ organization_id, subscription_id, @user.id ],
      [ call.fetch(:organization_id), call.fetch(:subscription_id), call.fetch(:actor_user).id ]
    assert_equal "billing_support.manage", call.fetch(:authorization).permission_key
  end

  private

  def grant(permission)
    Billing::SupportAccessGrant.create!(
      user_id: @user.id,
      permission: permission,
      granted_at: @now
    )
  end

  def dead_letter_event
    raw = JSON.generate(
      id: "provider-event-#{SecureRandom.hex(4)}",
      name: "subscription.updated",
      occurred_at: @now.iso8601
    )
    receiver = Billing::ReceiveWebhook.new(
      provider: Billing::FakeProvider.new(clock: -> { @now }),
      environment: "test",
      clock: -> { @now },
      enqueue: ->(_id) { }
    )
    receipt = receiver.call(
      raw_body: raw,
      headers: { "Content-Type" => "application/json", "X-Fake-Signature" => "valid" }
    )
    event = Billing::WebhookEvent.find(receipt.id)
    event.update!(
      state: "dead_letter",
      attempt_count: 1,
      last_attempted_at: @now,
      failed_at: @now,
      last_error_category: "mapping_missing"
    )
    event
  end
end
