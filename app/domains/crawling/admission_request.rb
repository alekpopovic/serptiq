# frozen_string_literal: true

require "digest"
require "json"

module Crawling
  AdmissionRequest = Data.define(
    :idempotency_key, :source, :project_id, :property_id, :environment_id,
    :scan_type, :baseline_scan_id, :release_id
  ) do
    SOURCES = %w[manual schedule release].freeze
    MAXIMUM_KEY_BYTES = 200

    def initialize(idempotency_key:, source:, project_id:, property_id:, environment_id:,
      scan_type:, baseline_scan_id: nil, release_id: nil)
      key = idempotency_key.to_s
      normalized_source = source.to_s
      identifiers = {
        project_id: project_id.to_s,
        property_id: property_id.to_s,
        environment_id: environment_id.to_s,
        baseline_scan_id: baseline_scan_id&.to_s,
        release_id: release_id&.to_s
      }
      valid = key.valid_encoding? && key.bytesize.between?(1, MAXIMUM_KEY_BYTES) &&
        SOURCES.include?(normalized_source) && Scan::SCAN_TYPES.include?(scan_type.to_s) &&
        identifiers.values_at(:project_id, :property_id, :environment_id).all? do |value|
          Shared::Public.application_uuid?(value)
        end
      valid &&= identifiers.values_at(:baseline_scan_id, :release_id).compact.all? do |value|
        Shared::Public.application_uuid?(value)
      end
      raise Invalid.new(
        field_errors: { request: "Use a valid target, scan type, source and idempotency key." },
        reason_code: "scan_admission_request_invalid"
      ) unless valid

      super(
        idempotency_key: key.freeze,
        source: normalized_source.freeze,
        scan_type: scan_type.to_s.freeze,
        **identifiers.transform_values { |value| value&.freeze }
      )
      freeze
    end

    def idempotency_digest
      Digest::SHA256.hexdigest(idempotency_key).freeze
    end

    def checksum
      Digest::SHA256.hexdigest(JSON.generate(checksum_payload)).freeze
    end

    def scan_id(organization_id:)
      hex = Digest::SHA256.hexdigest("scan-admission:#{organization_id}:#{idempotency_digest}").first(32)
      hex[12] = "5"
      hex[16] = ((hex[16].to_i(16) & 0x3) | 0x8).to_s(16)
      [ hex[0, 8], hex[8, 4], hex[12, 4], hex[16, 4], hex[20, 12] ].join("-").freeze
    end

    def initiator_type
      source == "manual" ? "membership" : source
    end

    private

    def checksum_payload
      {
        "baseline_scan_id" => baseline_scan_id,
        "environment_id" => environment_id,
        "project_id" => project_id,
        "property_id" => property_id,
        "release_id" => release_id,
        "scan_type" => scan_type,
        "source" => source
      }
    end
  end
end
