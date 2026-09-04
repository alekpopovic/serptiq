# frozen_string_literal: true

require "json"
require "time"

module Shared
  module Observability
    class EventEmitter
      EVENT_NAME_PATTERN = /\A[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+\z/
      LABEL_PATTERN = /\A[a-z][a-z0-9_.-]{0,63}\z/
      CLASS_NAME_PATTERN = /\A[A-Z]\w*(?:::[A-Z]\w*)*\z/
      SEVERITIES = %i[debug info warn error fatal].freeze
      OUTCOMES = %w[succeeded failed denied ignored retrying].freeze
      ALLOWED_ATTRIBUTES = %i[
        cause_classes duration_ms error_category error_code exception_class http_status
        operation outcome provider reason_code retry_count
      ].freeze

      def initialize(logger: Rails.logger, clock: -> { Time.current }, redaction: nil)
        @logger = logger
        @clock = clock
        @redaction = redaction || Rails.application.config.x.redaction
      end

      def emit(event_name, severity: :info, **attributes)
        validate_event_name!(event_name)
        validate_severity!(severity)
        validate_attributes!(attributes)
        context = Context.snapshot
        validate_context!(context)

        record = {
          "timestamp" => @clock.call.utc.iso8601(6),
          "severity" => severity.to_s,
          "event_name" => event_name,
          "event_version" => 1
        }.merge(context).merge(stringify(attributes))
        record = @redaction.structured_event(record)
        @logger.public_send(severity, JSON.generate(record))
        record.freeze
      end

      private

      def validate_event_name!(value)
        return if value.to_s.length <= 96 && EVENT_NAME_PATTERN.match?(value.to_s)

        raise ArgumentError, "event_name must be a bounded dotted identifier"
      end

      def validate_severity!(value)
        raise ArgumentError, "unsupported event severity" unless SEVERITIES.include?(value.to_sym)
      end

      def validate_attributes!(attributes)
        unknown = attributes.keys.map(&:to_sym) - ALLOWED_ATTRIBUTES
        raise ArgumentError, "unsupported event attributes: #{unknown.join(', ')}" if unknown.any?

        validate_non_negative_number!(:duration_ms, attributes[:duration_ms])
        validate_non_negative_integer!(:retry_count, attributes[:retry_count])
        validate_http_status!(attributes[:http_status])
        validate_outcome!(attributes[:outcome])
        %i[error_category error_code operation provider reason_code].each do |name|
          validate_label!(name, attributes[name])
        end
        validate_class_name!(:exception_class, attributes[:exception_class])
        validate_cause_classes!(attributes[:cause_classes])
      end

      def validate_context!(context)
        %w[request_id trace_id job_id release].each do |name|
          value = context[name]
          next if value.nil? || Context::CORRELATION_ID_PATTERN.match?(value.to_s)

          raise ArgumentError, "#{name} must be a bounded correlation identifier"
        end
        validate_label!(:environment, context["environment"])

        organization_hash = context["organization_id_hash"]
        if organization_hash && !Context::HASH_PATTERN.match?(organization_hash.to_s)
          raise ArgumentError, "organization_id_hash must be a keyed digest"
        end

        %w[actor_id_hash subject_id_hash role_id_hash scope_id_hash].each do |name|
          value = context[name]
          next if value.nil? || Context::HASH_PATTERN.match?(value.to_s)

          raise ArgumentError, "#{name} must be a keyed digest"
        end

        %w[project_id scan_id].each do |name|
          value = context[name]
          next if value.nil? || Context::RESOURCE_ID_PATTERN.match?(value.to_s)

          raise ArgumentError, "#{name} must be an application UUID"
        end


        %w[principal_type scope_type].each do |name|
          validate_label!(name, context[name])
        end
      end

      def validate_non_negative_number!(name, value)
        return if value.nil? || (value.is_a?(Numeric) && value.finite? && value >= 0)

        raise ArgumentError, "#{name} must be a non-negative finite number"
      end

      def validate_non_negative_integer!(name, value)
        return if value.nil? || (value.is_a?(Integer) && value >= 0)

        raise ArgumentError, "#{name} must be a non-negative integer"
      end

      def validate_http_status!(value)
        return if value.nil? || (value.is_a?(Integer) && value.between?(100, 599))

        raise ArgumentError, "http_status must be an HTTP status integer"
      end

      def validate_outcome!(value)
        return if value.nil? || OUTCOMES.include?(value.to_s)

        raise ArgumentError, "outcome must be a stable allowlisted value"
      end

      def validate_label!(name, value)
        return if value.nil? || LABEL_PATTERN.match?(value.to_s)

        raise ArgumentError, "#{name} must be a bounded low-cardinality label"
      end

      def validate_class_name!(name, value)
        return if value.nil? || CLASS_NAME_PATTERN.match?(value.to_s)

        raise ArgumentError, "#{name} must be a Ruby class name"
      end

      def validate_cause_classes!(value)
        return if value.nil?
        valid = value.is_a?(Array) && value.length.between?(1, 5) &&
          value.all? { |class_name| CLASS_NAME_PATTERN.match?(class_name.to_s) }
        raise ArgumentError, "cause_classes must contain at most five Ruby class names" unless valid
      end

      def stringify(attributes)
        attributes.compact.to_h { |key, value| [ key.to_s, value ] }
      end
    end
  end
end
