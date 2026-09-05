# frozen_string_literal: true

module Crawling
  class HttpFetchHop < Data.define(
    :sequence, :attempt_number, :redirect_index, :requested_url, :status,
    :location_url, :outcome, :failure_category, :resolution_provenance,
    :duration_ms, :header_bytes, :compressed_bytes, :decoded_bytes
  )
    OUTCOMES = %w[response redirect retry failed rejected canceled].freeze
    CATEGORY_PATTERN = /\A[a-z][a-z0-9_]{0,63}\z/

    def initialize(**attributes)
      sequence = Integer(attributes.fetch(:sequence))
      attempt = Integer(attributes.fetch(:attempt_number))
      redirect = Integer(attributes.fetch(:redirect_index))
      requested_url = attributes.fetch(:requested_url).to_s
      location_url = attributes[:location_url]&.to_s
      status = attributes[:status]&.then { |value| Integer(value) }
      outcome = attributes.fetch(:outcome).to_s
      category = attributes[:failure_category]&.to_s
      provenance = normalize_provenance(attributes[:resolution_provenance])
      duration = Integer(attributes.fetch(:duration_ms, 0))
      sizes = %i[header_bytes compressed_bytes decoded_bytes].to_h do |name|
        [ name, Integer(attributes.fetch(name, 0)) ]
      end
      valid = sequence.between?(1, 32) && attempt.between?(1, 10) && redirect.between?(0, 20) &&
        requested_url.bytesize.between?(1, 8192) && (location_url.nil? || location_url.bytesize.between?(1, 8192)) &&
        (status.nil? || status.between?(100, 599)) && OUTCOMES.include?(outcome) &&
        (category.nil? || CATEGORY_PATTERN.match?(category)) && duration.between?(0, 600_000) &&
        sizes.fetch(:header_bytes).between?(0, 262_144) &&
        sizes.fetch(:compressed_bytes).between?(0, 104_857_600) &&
        sizes.fetch(:decoded_bytes).between?(0, 524_288_000)
      raise ArgumentError, "HTTP fetch hop is invalid" unless valid

      super(
        sequence: sequence,
        attempt_number: attempt,
        redirect_index: redirect,
        requested_url: requested_url.freeze,
        status: status,
        location_url: location_url&.freeze,
        outcome: outcome.freeze,
        failure_category: category&.freeze,
        resolution_provenance: provenance,
        duration_ms: duration,
        **sizes
      )
      freeze
    end

    def inspect
      "#<#{self.class.name} sequence=#{sequence} status=#{status || "none"} outcome=#{outcome}>"
    end

    private

    def normalize_provenance(value)
      return if value.nil?

      source = value.to_h.transform_keys(&:to_sym)
      result = %i[address_count ipv4_address_count ipv6_address_count destination_port].to_h do |name|
        [ name, Integer(source.fetch(name)) ]
      end
      version = source.fetch(:address_policy_version).to_s
      valid = result.fetch(:destination_port).between?(1, 65_535) &&
        result.fetch(:address_count).between?(1, 16) &&
        result.values_at(:ipv4_address_count, :ipv6_address_count).all? { |item| item.between?(0, 16) } &&
        result.fetch(:address_count) ==
          result.fetch(:ipv4_address_count) + result.fetch(:ipv6_address_count) &&
        version == Shared::Public.network_address_policy_version
      raise ArgumentError, "HTTP fetch resolution provenance is invalid" unless valid

      result.merge(address_policy_version: version.freeze).freeze
    end
  end
end
