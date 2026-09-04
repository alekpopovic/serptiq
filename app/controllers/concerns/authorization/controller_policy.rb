# frozen_string_literal: true

module Authorization
  module ControllerPolicy
    extend ActiveSupport::Concern

    included do
      class_attribute :authorization_declarations,
        instance_accessor: false,
        default: {}.freeze
      helper_method :allowed_to?
    end

    class_methods do
      def permission_required(permission_key, only:, **conditions)
        declare_authorization(permission_key, only, :required)
        before_action(only: Array(only), **conditions) do
          authorize_permission!(permission_key)
        end
      end

      def permission_hint(permission_key, only:, **conditions)
        declare_authorization(permission_key, only, :hint)
        before_action(only: Array(only), **conditions) do
          remember_authorization_decision(permission_key)
        end
      end

      def authorization_exempt(*actions, reason:)
        raise ArgumentError, "authorization exemption requires a reason" if reason.to_s.blank?

        declare_authorization("exempt:#{reason}", actions, :exempt)
      end

      private

      def declare_authorization(permission_key, actions, kind)
        additions = authorization_declarations.deep_dup
        Array(actions).each do |action|
          action_name = action.to_s
          additions[action_name] ||= []
          additions[action_name] << { permission: permission_key.to_s, kind: kind.to_s }.freeze
          additions[action_name].freeze
        end
        self.authorization_declarations = additions.freeze
      end
    end

    private

    def authorization_policy
      PolicyAdapter.new(actor_membership: Current.membership, organization: Current.organization)
    end

    def authorize_permission!(permission_key, **scope)
      result = authorization_policy.authorize!(permission_key: permission_key, **scope)
      authorization_decisions[decision_cache_key(permission_key, scope)] = result
      result
    end

    def access_decision(permission_key, **attributes)
      authorization_policy.access_decision(permission_key: permission_key, **attributes)
    end

    def authorize_access!(permission_key, **attributes)
      authorization_policy.authorize_access!(permission_key: permission_key, **attributes)
    end

    def with_authorized_access(permission_key, **attributes, &block)
      authorization_policy.with_access(permission_key: permission_key, **attributes, &block)
    end

    def allowed_to?(permission_key, **scope)
      authorization_decisions.fetch(decision_cache_key(permission_key, scope), denied_hint).allow?
    end

    def authorization_decision!(permission_key, **scope)
      authorization_decisions.fetch(decision_cache_key(permission_key, scope)) do
        raise "authorization decision for #{permission_key} was not evaluated"
      end
    end

    def remember_authorization_decision(permission_key, **scope)
      key = decision_cache_key(permission_key, scope)
      authorization_decisions[key] = authorization_policy.decision(permission_key: permission_key, **scope)
    end

    def authorization_decisions
      @authorization_decisions ||= {}
    end

    def decision_cache_key(permission_key, scope)
      [ permission_key.to_s, scope.transform_values { |value| value.respond_to?(:id) ? value.id.to_s : value.to_s } ]
    end

    def denied_hint
      Authorization::DecisionResult.new(
        allowed: false,
        reason_code: "permission_not_preloaded",
        permission_key: "unknown.permission",
        organization_id: Current.organization&.id,
        scope_type: "Organization",
        scope_id: Current.organization&.id
      )
    end
  end
end
