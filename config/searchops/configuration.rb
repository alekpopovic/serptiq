# frozen_string_literal: true

require "ipaddr"
require "pathname"
require "uri"
require "yaml"

module Searchops
  class Configuration
    class Error < StandardError; end

    Definition = Data.define(:env_key, :type, :default, :minimum, :maximum, :values, :secret, :credential_path)

    ENVIRONMENTS = %w[development test staging production].freeze
    PROTECTED_ENVIRONMENTS = %w[staging production].freeze
    TRUE_VALUES = %w[1 true yes on].freeze
    FALSE_VALUES = %w[0 false no off].freeze
    DURATION_UNITS = { "ms" => 0.001, "s" => 1, "m" => 60, "h" => 3600 }.freeze

    DEFINITIONS = {
      application_name: Definition.new("SEARCHOPS_APPLICATION_NAME", :string, "SearchOps", nil, nil, nil, false, nil),
      application_origin: Definition.new("SEARCHOPS_APPLICATION_ORIGIN", :origin, nil, nil, nil, nil, false, nil),
      database_role: Definition.new("SEARCHOPS_DATABASE_ROLE", :enum, "web", nil, nil,
        %w[web scheduler worker test], false, nil),
      database_pool: Definition.new("RAILS_MAX_THREADS", :integer, 5, 1, 100, nil, false, nil),
      database_host: Definition.new("SEARCHOPS_DATABASE_HOST", :string, nil, nil, nil, nil, false, nil),
      database_port: Definition.new("SEARCHOPS_DATABASE_PORT", :integer, 5432, 1, 65_535, nil, false, nil),
      database_username: Definition.new("SEARCHOPS_DATABASE_USERNAME", :string, "searchops", nil, nil, nil, false, nil),
      primary_database_pool: Definition.new("SEARCHOPS_PRIMARY_DATABASE_POOL", :integer, 5, 1, 1000, nil, false, nil),
      queue_database_pool: Definition.new("SEARCHOPS_QUEUE_DATABASE_POOL", :integer, 5, 1, 1000, nil, false, nil),
      cache_database_pool: Definition.new("SEARCHOPS_CACHE_DATABASE_POOL", :integer, 2, 1, 1000, nil, false, nil),
      cable_database_pool: Definition.new("SEARCHOPS_CABLE_DATABASE_POOL", :integer, 2, 1, 1000, nil, false, nil),
      database_process_count: Definition.new("SEARCHOPS_DATABASE_PROCESS_COUNT", :integer, 1, 1, 1000, nil, false, nil),
      database_reserved_connections: Definition.new("SEARCHOPS_DATABASE_RESERVED_CONNECTIONS", :integer,
        5, 0, 1000, nil, false, nil),
      database_connection_budget: Definition.new("SEARCHOPS_DATABASE_CONNECTION_BUDGET", :integer,
        nil, 1, 100_000, nil, false, nil),
      database_connect_timeout_seconds: Definition.new("SEARCHOPS_DATABASE_CONNECT_TIMEOUT_SECONDS", :integer,
        3, 1, 30, nil, false, nil),
      database_checkout_timeout_seconds: Definition.new("SEARCHOPS_DATABASE_CHECKOUT_TIMEOUT_SECONDS", :integer,
        3, 1, 30, nil, false, nil),
      database_statement_timeout_ms: Definition.new("SEARCHOPS_DATABASE_STATEMENT_TIMEOUT_MS", :integer,
        15_000, 100, 300_000, nil, false, nil),
      database_lock_timeout_ms: Definition.new("SEARCHOPS_DATABASE_LOCK_TIMEOUT_MS", :integer,
        5_000, 100, 60_000, nil, false, nil),
      database_idle_transaction_timeout_ms: Definition.new("SEARCHOPS_DATABASE_IDLE_TRANSACTION_TIMEOUT_MS", :integer,
        30_000, 1000, 600_000, nil, false, nil),
      database_health_timeout_ms: Definition.new("SEARCHOPS_DATABASE_HEALTH_TIMEOUT_MS", :integer,
        1000, 50, 5000, nil, false, nil),
      database_advisory_locks: Definition.new("SEARCHOPS_DATABASE_ADVISORY_LOCKS", :boolean,
        true, nil, nil, nil, false, nil),
      object_storage_service: Definition.new("SEARCHOPS_OBJECT_STORAGE_SERVICE", :enum, "local", nil, nil,
        %w[local s3], false, nil),
      object_storage_bucket: Definition.new("SEARCHOPS_OBJECT_STORAGE_BUCKET", :string, nil, nil, nil, nil, false, nil),
      object_storage_region: Definition.new("SEARCHOPS_OBJECT_STORAGE_REGION", :string, nil, nil, nil, nil, false, nil),
      object_storage_endpoint: Definition.new("SEARCHOPS_OBJECT_STORAGE_ENDPOINT", :origin, nil, nil, nil, nil, false, nil),
      oauth_google_enabled: Definition.new("SEARCHOPS_OAUTH_GOOGLE_ENABLED", :boolean, false, nil, nil, nil, false, nil),
      oauth_google_client_id: Definition.new("SEARCHOPS_OAUTH_GOOGLE_CLIENT_ID", :string, nil, nil, nil, nil, false, nil),
      oauth_github_enabled: Definition.new("SEARCHOPS_OAUTH_GITHUB_ENABLED", :boolean, false, nil, nil, nil, false, nil),
      oauth_github_client_id: Definition.new("SEARCHOPS_OAUTH_GITHUB_CLIENT_ID", :string, nil, nil, nil, nil, false, nil),
      oauth_http_open_timeout: Definition.new("SEARCHOPS_OAUTH_HTTP_OPEN_TIMEOUT", :duration, "2s",
        0.1, 10, nil, false, nil),
      oauth_http_read_timeout: Definition.new("SEARCHOPS_OAUTH_HTTP_READ_TIMEOUT", :duration, "5s",
        0.1, 30, nil, false, nil),
      oauth_http_max_response_bytes: Definition.new("SEARCHOPS_OAUTH_HTTP_MAX_RESPONSE_BYTES", :integer,
        262_144, 1024, 1_048_576, nil, false, nil),
      oauth_http_safe_retries: Definition.new("SEARCHOPS_OAUTH_HTTP_SAFE_RETRIES", :integer,
        2, 0, 3, nil, false, nil),
      billing_provider: Definition.new("SEARCHOPS_BILLING_PROVIDER", :enum, "disabled", nil, nil,
        %w[disabled lemon_squeezy], false, nil),
      billing_store_id: Definition.new("SEARCHOPS_BILLING_STORE_ID", :string, nil, nil, nil, nil, false, nil),
      encryption_key_version: Definition.new("SEARCHOPS_ENCRYPTION_KEY_VERSION", :string, "v1", nil, nil, nil, false, nil),
      crawler_max_urls_per_scan: Definition.new("SEARCHOPS_CRAWLER_MAX_URLS_PER_SCAN", :integer, 10_000,
        1, 1_000_000, nil, false, nil),
      crawler_connect_timeout: Definition.new("SEARCHOPS_CRAWLER_CONNECT_TIMEOUT", :duration, "5s",
        0.1, 60, nil, false, nil),
      crawler_read_timeout: Definition.new("SEARCHOPS_CRAWLER_READ_TIMEOUT", :duration, "20s",
        1, 300, nil, false, nil),
      crawler_max_response_bytes: Definition.new("SEARCHOPS_CRAWLER_MAX_RESPONSE_BYTES", :integer, 10_485_760,
        1024, 104_857_600, nil, false, nil),
      crawler_max_redirects: Definition.new("SEARCHOPS_CRAWLER_MAX_REDIRECTS", :integer, 5, 0, 20, nil, false, nil),
      crawler_concurrency: Definition.new("SEARCHOPS_CRAWLER_CONCURRENCY", :integer, 8, 1, 1000, nil, false, nil),
      browser_timeout: Definition.new("SEARCHOPS_BROWSER_TIMEOUT", :duration, "45s", 1, 300, nil, false, nil),
      browser_memory_mb: Definition.new("SEARCHOPS_BROWSER_MEMORY_MB", :integer, 1024, 256, 8192, nil, false, nil),
      browser_max_requests: Definition.new("SEARCHOPS_BROWSER_MAX_REQUESTS", :integer, 200, 1, 5000, nil, false, nil),
      browser_concurrency: Definition.new("SEARCHOPS_BROWSER_CONCURRENCY", :integer, 2, 1, 100, nil, false, nil),
      search_console_enabled: Definition.new("SEARCHOPS_SEARCH_CONSOLE_ENABLED", :boolean, false, nil, nil, nil, false, nil),
      pagespeed_enabled: Definition.new("SEARCHOPS_PAGESPEED_ENABLED", :boolean, false, nil, nil, nil, false, nil),
      crux_enabled: Definition.new("SEARCHOPS_CRUX_ENABLED", :boolean, false, nil, nil, nil, false, nil),
      email_delivery_method: Definition.new("SEARCHOPS_EMAIL_DELIVERY_METHOD", :enum, "log", nil, nil,
        %w[log test smtp], false, nil),
      email_from: Definition.new("SEARCHOPS_EMAIL_FROM", :string, nil, nil, nil, nil, false, nil),
      smtp_host: Definition.new("SEARCHOPS_SMTP_HOST", :string, nil, nil, nil, nil, false, nil),
      smtp_port: Definition.new("SEARCHOPS_SMTP_PORT", :integer, 587, 1, 65_535, nil, false, nil),
      smtp_username: Definition.new("SEARCHOPS_SMTP_USERNAME", :string, nil, nil, nil, nil, false, nil),
      slack_enabled: Definition.new("SEARCHOPS_SLACK_ENABLED", :boolean, false, nil, nil, nil, false, nil),
      slack_client_id: Definition.new("SEARCHOPS_SLACK_CLIENT_ID", :string, nil, nil, nil, nil, false, nil),
      log_level: Definition.new("RAILS_LOG_LEVEL", :enum, "info", nil, nil,
        %w[debug info warn error fatal], false, nil),
      tracing_enabled: Definition.new("SEARCHOPS_TRACING_ENABLED", :boolean, false, nil, nil, nil, false, nil),
      observability_endpoint: Definition.new("SEARCHOPS_OBSERVABILITY_ENDPOINT", :origin, nil, nil, nil, nil, false, nil),
      release_sha: Definition.new("SEARCHOPS_RELEASE_SHA", :string, nil, nil, nil, nil, false, nil),
      build_timestamp: Definition.new("SEARCHOPS_BUILD_TIMESTAMP", :string, nil, nil, nil, nil, false, nil),
      process_role: Definition.new("SEARCHOPS_PROCESS_ROLE", :enum, "web", nil, nil,
        %w[web scheduler worker_default worker_crawl worker_render worker_analysis worker_report], false, nil),
      secret_key_base: Definition.new("SECRET_KEY_BASE", :secret, nil, nil, nil, nil, true, [ :secret_key_base ]),
      database_url: Definition.new("DATABASE_URL", :database_url, nil, nil, nil, nil, true, [ :database, :url ]),
      queue_database_url: Definition.new("QUEUE_DATABASE_URL", :database_url,
        nil, nil, nil, nil, true, [ :database, :queue_url ]),
      cache_database_url: Definition.new("CACHE_DATABASE_URL", :database_url,
        nil, nil, nil, nil, true, [ :database, :cache_url ]),
      cable_database_url: Definition.new("CABLE_DATABASE_URL", :database_url,
        nil, nil, nil, nil, true, [ :database, :cable_url ]),
      database_password: Definition.new("SEARCHOPS_DATABASE_PASSWORD", :secret, nil, nil, nil, nil, true,
        [ :database, :password ]),
      object_storage_access_key_id: Definition.new("SEARCHOPS_OBJECT_STORAGE_ACCESS_KEY_ID", :secret,
        nil, nil, nil, nil, true, [ :object_storage, :access_key_id ]),
      object_storage_secret_access_key: Definition.new("SEARCHOPS_OBJECT_STORAGE_SECRET_ACCESS_KEY", :secret,
        nil, nil, nil, nil, true, [ :object_storage, :secret_access_key ]),
      encryption_primary_keys: Definition.new("ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEYS", :secret_list, nil,
        nil, nil, nil, true, [ :active_record_encryption, :primary_keys ]),
      encryption_deterministic_key: Definition.new("ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY", :secret,
        nil, nil, nil, nil, true, [ :active_record_encryption, :deterministic_key ]),
      encryption_key_derivation_salt: Definition.new("ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT", :secret,
        nil, nil, nil, nil, true, [ :active_record_encryption, :key_derivation_salt ]),
      oauth_google_client_secret: Definition.new("SEARCHOPS_OAUTH_GOOGLE_CLIENT_SECRET", :secret,
        nil, nil, nil, nil, true, [ :oauth, :google, :client_secret ]),
      oauth_github_client_secret: Definition.new("SEARCHOPS_OAUTH_GITHUB_CLIENT_SECRET", :secret,
        nil, nil, nil, nil, true, [ :oauth, :github, :client_secret ]),
      provider_google_api_key: Definition.new("SEARCHOPS_PROVIDER_GOOGLE_API_KEY", :secret,
        nil, nil, nil, nil, true, [ :providers, :google_api_key ]),
      billing_api_key: Definition.new("SEARCHOPS_BILLING_API_KEY", :secret,
        nil, nil, nil, nil, true, [ :billing, :api_key ]),
      billing_webhook_secret: Definition.new("SEARCHOPS_BILLING_WEBHOOK_SECRET", :secret,
        nil, nil, nil, nil, true, [ :billing, :webhook_secret ]),
      smtp_password: Definition.new("SEARCHOPS_SMTP_PASSWORD", :secret,
        nil, nil, nil, nil, true, [ :email, :smtp_password ]),
      slack_client_secret: Definition.new("SEARCHOPS_SLACK_CLIENT_SECRET", :secret,
        nil, nil, nil, nil, true, [ :slack, :client_secret ]),
      slack_signing_secret: Definition.new("SEARCHOPS_SLACK_SIGNING_SECRET", :secret,
        nil, nil, nil, nil, true, [ :slack, :signing_secret ]),
      observability_auth_token: Definition.new("SEARCHOPS_OBSERVABILITY_AUTH_TOKEN", :secret,
        nil, nil, nil, nil, true, [ :observability, :auth_token ]),
      webhook_signing_keys: Definition.new("SEARCHOPS_WEBHOOK_SIGNING_KEYS", :secret_list,
        nil, nil, nil, nil, true, [ :webhooks, :signing_keys ])
    }.freeze

    attr_reader :environment

    def self.load(environment:, env: ENV, credentials: {}, path:)
      new(environment: environment, env: env, credentials: credentials, path: path).tap(&:validate!)
    end

    def initialize(environment:, env:, credentials:, path:)
      @environment = environment.to_s
      @env = env
      @credentials = credentials || {}
      @path = Pathname(path)
      @values = load_values
    end

    def fetch(key)
      definition = definition_for(key)
      raise ArgumentError, "#{key} is secret; use #secret" if definition.secret

      @values.fetch(key.to_sym)
    end

    def secret(key)
      definition = definition_for(key)
      raise ArgumentError, "#{key} is public; use #fetch" unless definition.secret

      @values.fetch(key.to_sym)
    end

    def to_h
      @values.to_h do |key, value|
        [ key, DEFINITIONS.fetch(key).secret && present?(value) ? "[FILTERED]" : value ]
      end
    end

    def inspect
      "#<#{self.class.name} environment=#{environment.inspect} values=#{to_h.inspect}>"
    end

    def validate!
      errors = []
      errors << "unsupported environment #{environment.inspect}" unless ENVIRONMENTS.include?(environment)
      validate_protected_environment(errors) if PROTECTED_ENVIRONMENTS.include?(environment)
      validate_integrations(errors)
      raise Error, "Invalid SearchOps configuration (#{environment}): #{errors.join('; ')}" if errors.any?

      self
    end

    private

    def definition_for(key)
      DEFINITIONS.fetch(key.to_sym)
    rescue KeyError
      raise ArgumentError, "unknown setting #{key.inspect}"
    end

    def load_values
      file_values = configuration_file_values

      DEFINITIONS.to_h do |key, definition|
        environment_override = environment_value(definition.env_key)
        raw_value = if definition.secret
          secret_value(definition)
        elsif environment_override
          environment_override
        elsif file_values.key?(key.to_s)
          file_values.fetch(key.to_s)
        else
          definition.default
        end
        [ key, parse(key, raw_value, definition) ]
      end
    end

    def configuration_file_values
      contents = YAML.safe_load_file(@path, aliases: false) || {}
      unknown_environments = contents.keys - [ "shared", *ENVIRONMENTS ]
      raise Error, "Unknown configuration sections: #{unknown_environments.join(', ')}" if unknown_environments.any?

      values = contents.fetch("shared", {}).merge(contents.fetch(environment, {}))
      unknown_keys = values.keys - DEFINITIONS.keys.map(&:to_s)
      raise Error, "Unknown configuration keys: #{unknown_keys.join(', ')}" if unknown_keys.any?

      secret_keys = values.keys.select { |key| DEFINITIONS.fetch(key.to_sym).secret }
      raise Error, "Secrets are not allowed in #{@path}: #{secret_keys.join(', ')}" if secret_keys.any?

      values
    end

    def secret_value(definition)
      environment_value(definition.env_key) || credential_value(definition.credential_path)
    end

    def environment_value(key)
      value = @env[key]
      value unless value.nil? || value.strip.empty?
    end

    def credential_value(path)
      return if path.nil?

      value = @credentials.dig(*path)
      value unless value.respond_to?(:empty?) && value.empty?
    end

    def parse(key, raw_value, definition)
      return if raw_value.nil?

      case definition.type
      when :string, :secret then raw_value.to_s
      when :database_url then parse_database_url(key, raw_value)
      when :secret_list then parse_secret_list(raw_value)
      when :integer then parse_integer(key, raw_value, definition)
      when :boolean then parse_boolean(key, raw_value)
      when :duration then parse_duration(key, raw_value, definition)
      when :origin then parse_origin(key, raw_value)
      when :enum then parse_enum(key, raw_value, definition)
      else raise Error, "Unsupported type for #{definition.env_key}"
      end
    end

    def parse_secret_list(raw_value)
      Array(raw_value.is_a?(String) ? raw_value.split(",") : raw_value).map(&:strip).reject(&:empty?).freeze
    end

    def parse_database_url(key, raw_value)
      uri = URI.parse(raw_value.to_s)
      invalid!(key, "must use postgresql:// or postgres://") unless %w[postgresql postgres].include?(uri.scheme)
      raw_value.to_s
    rescue URI::InvalidURIError
      invalid!(key, "must be a valid PostgreSQL URL")
    end

    def parse_integer(key, raw_value, definition)
      value = Integer(raw_value.to_s, 10)
      validate_bounds!(key, value, definition)
    rescue ArgumentError
      invalid!(key, "must be an integer")
    end

    def parse_boolean(key, raw_value)
      normalized = raw_value.to_s.downcase
      return true if TRUE_VALUES.include?(normalized)
      return false if FALSE_VALUES.include?(normalized)

      invalid!(key, "must be a boolean")
    end

    def parse_duration(key, raw_value, definition)
      match = /\A(\d+(?:\.\d+)?)(ms|s|m|h)\z/.match(raw_value.to_s)
      invalid!(key, "must be a duration using ms, s, m, or h") unless match

      seconds = Float(match[1]) * DURATION_UNITS.fetch(match[2])
      validate_bounds!(key, seconds, definition)
    end

    def parse_origin(key, raw_value)
      uri = URI.parse(raw_value.to_s)
      valid = %w[http https].include?(uri.scheme) && uri.host && !uri.userinfo &&
        (uri.path.empty? || uri.path == "/") && !uri.query && !uri.fragment
      invalid!(key, "must be an HTTP(S) origin without credentials, path, query, or fragment") unless valid
      if PROTECTED_ENVIRONMENTS.include?(environment) && (uri.scheme != "https" || local_host?(uri.host))
        invalid!(key, "must be a public HTTPS origin in #{environment}")
      end

      uri.freeze
    rescue URI::InvalidURIError
      invalid!(key, "must be a valid HTTP(S) origin")
    end

    def parse_enum(key, raw_value, definition)
      value = raw_value.to_s
      invalid!(key, "must be one of #{definition.values.join(', ')}") unless definition.values.include?(value)
      value.freeze
    end

    def validate_bounds!(key, value, definition)
      invalid!(key, "must be at least #{definition.minimum}") if definition.minimum && value < definition.minimum
      invalid!(key, "must be at most #{definition.maximum}") if definition.maximum && value > definition.maximum
      value
    end

    def validate_protected_environment(errors)
      require_settings(errors, :application_origin, :release_sha, :database_connection_budget)
      require_secrets(errors, :secret_key_base, :encryption_primary_keys,
        :encryption_deterministic_key, :encryption_key_derivation_salt)
      if present?(secret(:database_url))
        require_secrets(errors, :queue_database_url, :cache_database_url, :cable_database_url)
      elsif present?(secret(:database_password))
        require_settings(errors, :database_host, :database_username)
      else
        errors << "one of DATABASE_URL or SEARCHOPS_DATABASE_PASSWORD is required"
      end
      if fetch(:object_storage_service) == "s3"
        require_settings(errors, :object_storage_bucket, :object_storage_region)
      end
    end

    def validate_integrations(errors)
      if fetch(:oauth_google_enabled)
        require_settings(errors, :oauth_google_client_id)
        require_secrets(errors, :oauth_google_client_secret)
      end
      if fetch(:oauth_github_enabled)
        require_settings(errors, :oauth_github_client_id)
        require_secrets(errors, :oauth_github_client_secret)
      end
      if fetch(:search_console_enabled) && !fetch(:oauth_google_enabled)
        errors << "SEARCHOPS_SEARCH_CONSOLE_ENABLED requires SEARCHOPS_OAUTH_GOOGLE_ENABLED"
      end
      if fetch(:pagespeed_enabled) || fetch(:crux_enabled)
        require_secrets(errors, :provider_google_api_key)
      end
      if fetch(:billing_provider) == "lemon_squeezy"
        require_settings(errors, :billing_store_id)
        require_secrets(errors, :billing_api_key, :billing_webhook_secret)
      end
      if fetch(:email_delivery_method) == "smtp"
        require_settings(errors, :email_from, :smtp_host, :smtp_username)
        require_secrets(errors, :smtp_password)
      end
      if fetch(:slack_enabled)
        require_settings(errors, :slack_client_id)
        require_secrets(errors, :slack_client_secret, :slack_signing_secret)
      end
      validate_database_capacity(errors)
    end

    def validate_database_capacity(errors)
      budget = fetch(:database_connection_budget)
      return unless budget

      pools = %i[primary_database_pool queue_database_pool cache_database_pool cable_database_pool]
      demand = pools.sum { |key| fetch(key) } * fetch(:database_process_count) + fetch(:database_reserved_connections)
      if demand > budget
        errors << "database connection demand #{demand} exceeds SEARCHOPS_DATABASE_CONNECTION_BUDGET #{budget}"
      end
      if fetch(:primary_database_pool) < fetch(:database_pool) && fetch(:database_role) == "web"
        errors << "SEARCHOPS_PRIMARY_DATABASE_POOL must be at least RAILS_MAX_THREADS for web processes"
      end
    end

    def require_settings(errors, *keys)
      keys.each do |key|
        errors << "#{DEFINITIONS.fetch(key).env_key} is required" unless present?(fetch(key))
      end
    end

    def require_secrets(errors, *keys)
      keys.each do |key|
        errors << "secret #{DEFINITIONS.fetch(key).env_key} is required" unless present?(secret(key))
      end
    end

    def present?(value)
      value.respond_to?(:empty?) ? !value.empty? : !value.nil?
    end

    def local_host?(host)
      normalized = host.downcase
      return true if normalized == "localhost" || normalized.end_with?(".localhost", ".local", ".internal", ".test")

      IPAddr.new(normalized).private? || IPAddr.new(normalized).loopback? || IPAddr.new(normalized).link_local?
    rescue IPAddr::InvalidAddressError
      false
    end

    def invalid!(key, message)
      raise Error, "Invalid #{DEFINITIONS.fetch(key).env_key}: #{message}"
    end
  end
end
