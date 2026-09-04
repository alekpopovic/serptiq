# frozen_string_literal: true

class VerificationFactory
  class_attribute :search_console_client_builder,
    default: -> { Integrations::Public.unconfigured_search_console_client }

  class << self
    def adapter_registry(settings: Rails.application.config.x.searchops)
      dns_adapter = settings.fetch(:dns_verification_enabled) ? build_dns_adapter(settings: settings) : nil
      http_fetcher = settings.fetch(:http_verification_enabled) ? build_http_fetcher(settings: settings) : nil
      search_console_client = self.search_console_client
      adapters = Verification::Challenge::METHODS.to_h do |method|
        adapter = case method
        when "dns_txt" then dns_adapter
        when "html_file" then Verification::Adapters::HtmlFile.new(fetcher: http_fetcher) if http_fetcher
        when "meta_tag" then Verification::Adapters::MetaTag.new(fetcher: http_fetcher) if http_fetcher
        when "search_console"
          Verification::Adapters::SearchConsole.new(client: search_console_client) if
            settings.fetch(:search_console_enabled)
        end
        adapter ||= Verification::Adapters::Unconfigured.new(method: method)
        [ method, adapter ]
      end
      Verification::AdapterRegistry.new(adapters: adapters)
    end

    def dns_rechecker(settings: Rails.application.config.x.searchops, clock: -> { Time.current })
      Verification::RecheckDnsChallenge.new(
        adapter: build_dns_adapter(settings: settings, clock: clock),
        clock: clock
      )
    end

    def dns_recheck_scheduler(clock: -> { Time.current })
      Verification::ScheduleDnsRechecks.new(clock: clock)
    end

    def search_console_client
      search_console_client_builder.call
    end

    private

    def build_dns_adapter(settings:, clock: -> { Time.current })
      resolver = Verification::DnsResolver.new(
        timeout: settings.fetch(:dns_verification_timeout),
        max_records: settings.fetch(:dns_verification_max_records),
        max_response_bytes: settings.fetch(:dns_verification_max_response_bytes),
        max_cname_hops: settings.fetch(:dns_verification_max_cname_hops),
        max_delegations: settings.fetch(:dns_verification_max_delegations)
      )
      Verification::Adapters::DnsTxt.new(resolver: resolver, clock: clock)
    end

    def build_http_fetcher(settings:)
      Shared::Public.safe_http_client(
        dns_timeout: settings.fetch(:verification_http_dns_timeout),
        open_timeout: settings.fetch(:verification_http_open_timeout),
        read_timeout: settings.fetch(:verification_http_read_timeout),
        max_response_bytes: settings.fetch(:verification_http_max_response_bytes),
        max_redirects: settings.fetch(:verification_http_max_redirects)
      )
    end
  end
end
