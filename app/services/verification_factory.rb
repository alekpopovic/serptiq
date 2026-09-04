# frozen_string_literal: true

class VerificationFactory
  class << self
    def adapter_registry(settings: Rails.application.config.x.searchops)
      dns_adapter = settings.fetch(:dns_verification_enabled) ? build_dns_adapter(settings: settings) : nil
      adapters = Verification::Challenge::METHODS.to_h do |method|
        adapter = if method == "dns_txt" && dns_adapter
          dns_adapter
        else
          Verification::Adapters::Unconfigured.new(method: method)
        end
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
  end
end
