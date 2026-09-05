# frozen_string_literal: true

require "pathname"
require "yaml"

root = Pathname(__dir__).join("..").expand_path
require root.join("app/domains/shared/network_safety/address_policy")

path = root.join("config/crawler_egress_policy.yml")
policy = YAML.safe_load_file(path, aliases: false)
errors = []
address_policy = Shared::NetworkSafety::AddressPolicy

errors << "version must be 1" unless policy.fetch("version") == 1
errors << "policy version is stale" unless
  policy.fetch("policy_version") == address_policy::POLICY_VERSION
errors << "protected worker roles are incomplete" unless
  policy.fetch("protected_worker_roles").sort == %w[worker_crawl worker_render]
errors << "runtime attestation key is invalid" unless
  policy.fetch("runtime_attestation") == "SEARCHOPS_CRAWLER_EGRESS_ENFORCED"
errors << "infrastructure policy must default-deny" unless policy.fetch("default_action") == "deny"
errors << "DNS must use an explicit resolver allowlist" unless
  policy.dig("dns", "resolver_allowlist_required") == true
errors << "DNS egress must be limited to TCP/UDP port 53" unless
  policy.dig("dns", "destination_port") == 53 && policy.dig("dns", "transports").sort == %w[tcp udp]
errors << "HTTP egress ports must match application policy" unless
  policy.dig("http", "destination_ports") == address_policy::ALLOWED_PORTS

ipv4_ranges = policy.fetch("ipv4_denied_cidrs").map { |cidr| IPAddr.new(cidr) }
ipv6_ranges = policy.fetch("ipv6_denied_cidrs").map { |cidr| IPAddr.new(cidr) }
errors << "IPv4 deny ranges differ from application policy" unless
  ipv4_ranges == address_policy::IPV4_BLOCKED_NETWORKS
errors << "IPv6 deny ranges differ from application policy" unless
  ipv6_ranges == address_policy::IPV6_BLOCKED_NETWORKS
errors << "IPv6 public-unicast allow range differs from application policy" unless
  IPAddr.new(policy.fetch("ipv6_allowed_unicast_cidr")) == address_policy::IPV6_GLOBAL_UNICAST

abort(errors.join("\n")) if errors.any?

puts "Crawler egress policy: passed"
