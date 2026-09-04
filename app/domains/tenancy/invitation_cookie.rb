# frozen_string_literal: true

module Tenancy
  class InvitationCookie
    DEVELOPMENT_NAME = "searchops_invitation"
    PROTECTED_NAME = "__Host-searchops_invitation"
    MAX_AGE = 2.hours

    def self.name(environment: Rails.env)
      protected_environment?(environment) ? PROTECTED_NAME : DEVELOPMENT_NAME
    end

    def self.protected_environment?(environment)
      Searchops::Configuration::PROTECTED_ENVIRONMENTS.include?(environment.to_s)
    end
    private_class_method :protected_environment?

    def initialize(cookie_jar, environment: Rails.env, clock: -> { Time.current })
      @cookie_jar = cookie_jar
      @environment = environment.to_s
      @clock = clock
    end

    def read
      @cookie_jar.encrypted[self.class.name(environment: @environment)]
    end

    def write(token:)
      raise ArgumentError, "invalid invitation token" unless InvitationToken.valid?(token)

      @cookie_jar.encrypted[self.class.name(environment: @environment)] = options.merge(
        value: token,
        expires: @clock.call + MAX_AGE
      )
    end

    def delete
      @cookie_jar.delete(self.class.name(environment: @environment), **options)
    end

    private

    def options
      {
        path: "/",
        httponly: true,
        secure: self.class.send(:protected_environment?, @environment),
        same_site: :lax
      }
    end
  end
end
