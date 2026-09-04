# frozen_string_literal: true

require "date"
require "pathname"
require "ripper"
require "yaml"

module Searchops
  module Architecture
    Violation = Data.define(:path, :line, :source, :target, :constant, :reason) do
      def to_s
        "#{path}:#{line}: #{source} -> #{target} (#{constant}): #{reason}"
      end
    end

    class BoundaryChecker
      IGNORED_TOKEN_TYPES = %i[
        on_sp on_nl on_ignored_nl on_comment on_embdoc on_embdoc_beg on_embdoc_end
      ].freeze
      REQUIRED_EXCEPTION_FIELDS = %w[
        source target path_pattern constant_pattern reason owner expires_on
      ].freeze

      attr_reader :root, :config_path

      def initialize(root:, config_path:)
        @root = Pathname(root).expand_path
        @config_path = Pathname(config_path).expand_path
        @config = YAML.safe_load_file(@config_path, permitted_classes: [ Date ], aliases: false)
        validate_config!
      end

      def check
        owned_ruby_files.flat_map do |source_key, path|
          references_in(path).filter_map do |reference|
            violation_for(source_key, path, reference)
          end
        end.sort_by { |violation| [ violation.path, violation.line, violation.constant ] }
      end

      private

      Reference = Data.define(:constant, :line)

      def validate_config!
        raise ArgumentError, "architecture config version must be 1" unless @config.fetch("version") == 1

        modules.each do |key, settings|
          unknown = settings.fetch("allowed_dependencies") - modules.keys
          raise ArgumentError, "#{key} has unknown dependencies: #{unknown.join(', ')}" if unknown.any?
        end

        exceptions.each_with_index do |exception, index|
          missing = REQUIRED_EXCEPTION_FIELDS - exception.keys
          raise ArgumentError, "exception #{index} is missing: #{missing.join(', ')}" if missing.any?
          raise ArgumentError, "exception #{index} has expired" if Date.parse(exception.fetch("expires_on")) < Date.today
        end
      end

      def modules
        @modules ||= @config.fetch("modules")
      end

      def exceptions
        @exceptions ||= @config.fetch("exceptions", [])
      end

      def namespaces
        @namespaces ||= modules.to_h { |key, settings| [ settings.fetch("namespace"), key ] }
      end

      def owned_ruby_files
        @config.fetch("source_roots").flat_map do |source_root|
          base = root.join(source_root)
          next [] unless base.directory?

          base.glob("**/*.rb").filter_map do |path|
            relative = path.relative_path_from(base)
            owner = relative.each_filename.first
            [ owner, path ] if modules.key?(owner)
          end
        end
      end

      def references_in(path)
        tokens = Ripper.lex(path.read).reject { |token| IGNORED_TOKEN_TYPES.include?(token[1]) }

        tokens.each_with_index.filter_map do |token, index|
          position, type, value = token
          next unless type == :on_const
          next if index >= 2 && tokens[index - 1][2] == "::" && tokens[index - 2][1] == :on_const

          parts = [ value ]
          cursor = index + 1
          while scope_operator?(tokens[cursor]) && constant_token?(tokens[cursor + 1])
            parts << tokens[cursor + 1][2]
            cursor += 2
          end

          Reference.new(parts.join("::"), position.first) if namespaces.key?(parts.first)
        end
      end

      def scope_operator?(token)
        token && token[2] == "::"
      end

      def constant_token?(token)
        token && token[1] == :on_const
      end

      def violation_for(source_key, path, reference)
        target_namespace, visibility = reference.constant.split("::", 3)
        target_key = namespaces.fetch(target_namespace)
        return if target_key == source_key

        reason = if !modules.fetch(source_key).fetch("allowed_dependencies").include?(target_key)
          "dependency is not allowed"
        elsif visibility != "Public"
          "cross-module references must use #{target_namespace}::Public"
        end
        return unless reason
        return if excepted?(source_key, target_key, path, reference)

        Violation.new(
          path.relative_path_from(root).to_s,
          reference.line,
          source_key,
          target_key,
          reference.constant,
          reason
        )
      end

      def excepted?(source_key, target_key, path, reference)
        relative_path = path.relative_path_from(root).to_s

        exceptions.any? do |exception|
          exception.fetch("source") == source_key &&
            exception.fetch("target") == target_key &&
            File.fnmatch?(exception.fetch("path_pattern"), relative_path) &&
            File.fnmatch?(exception.fetch("constant_pattern"), reference.constant)
        end
      end
    end
  end
end
