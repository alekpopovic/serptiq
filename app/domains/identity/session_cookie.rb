# frozen_string_literal: true

module Identity
  class SessionCookie
    DEVELOPMENT_NAME = "searchops_session"
    PROTECTED_NAME = "__Host-searchops_session"
    PATH = "/"

    def self.name(environment: Rails.env)
      protected_environment?(environment) ? PROTECTED_NAME : DEVELOPMENT_NAME
    end

    def self.protected_environment?(environment)
      Searchops::Configuration::PROTECTED_ENVIRONMENTS.include?(environment.to_s)
    end
    private_class_method :protected_environment?

    def initialize(cookie_jar, environment: Rails.env)
      @cookie_jar = cookie_jar
      @environment = environment.to_s
    end

    def read
      @cookie_jar[self.class.name(environment: @environment)]
    end

    def write(token:, expires_at:)
      @cookie_jar[self.class.name(environment: @environment)] = options.merge(
        value: token,
        expires: expires_at
      )
    end

    def delete
      @cookie_jar.delete(self.class.name(environment: @environment), **options)
    end

    def options
      {
        path: PATH,
        httponly: true,
        secure: self.class.send(:protected_environment?, @environment),
        same_site: :lax
      }.freeze
    end
  end
end
