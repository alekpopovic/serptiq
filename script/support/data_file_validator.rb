# frozen_string_literal: true

require "erb"
require "json"
require "pathname"
require "psych"

module Searchops
  module Quality
    class DataFileValidator
      EXCLUDED_PREFIXES = %w[
        .bundle/
        .git/
        app/assets/builds/
        log/
        node_modules/
        public/assets/
        storage/
        tmp/
        vendor/
      ].freeze

      attr_reader :root

      def initialize(root:, paths: nil, erb_binding: TOPLEVEL_BINDING)
        @root = Pathname(root).expand_path
        @paths = paths&.map { |path| Pathname(path).expand_path }
        @erb_binding = erb_binding
      end

      def validate
        files.flat_map { |path| errors_for(path) }
      end

      def files
        candidates = @paths || root.glob("**/*.{json,yaml,yml}", File::FNM_DOTMATCH)
        candidates.select(&:file?).reject { |path| excluded?(path) }.sort
      end

      private

      attr_reader :erb_binding

      def excluded?(path)
        relative = path.relative_path_from(root).to_s
        EXCLUDED_PREFIXES.any? { |prefix| relative.start_with?(prefix) }
      rescue ArgumentError
        true
      end

      def errors_for(path)
        case path.extname
        when ".json"
          validate_json(path)
        when ".yaml", ".yml"
          validate_yaml(path)
        else
          []
        end
      end

      def validate_json(path)
        JSON.parse(read_utf8(path), create_additions: false, allow_duplicate_key: false)
        []
      rescue JSON::ParserError, EncodingError => e
        [ "#{relative(path)}: invalid JSON: #{first_line(e.message)}" ]
      end

      def validate_yaml(path)
        rendered = render_erb(path, read_utf8(path))
        stream = Psych.parse_stream(rendered, filename: relative(path))
        duplicate_errors(stream, path)
      rescue Psych::Exception, SyntaxError, StandardError => e
        [ "#{relative(path)}: invalid YAML/ERB: #{first_line(e.message)}" ]
      end

      def render_erb(path, source)
        executable_erb = source.each_line.any? do |line|
          line.include?("<%") && !line.lstrip.start_with?("#")
        end
        return source unless executable_erb

        template = ERB.new(source)
        RubyVM::InstructionSequence.compile(template.src, relative(path)) if defined?(RubyVM::InstructionSequence)
        template.result(erb_binding)
      end

      def duplicate_errors(node, path, location = [])
        errors = []
        if node.is_a?(Psych::Nodes::Mapping)
          scalar_keys = node.children.each_slice(2).filter_map do |key, _value|
            key.value if key.is_a?(Psych::Nodes::Scalar)
          end
          scalar_keys.tally.select { |_key, count| count > 1 }.each_key do |key|
            errors << "#{relative(path)}: duplicate YAML key #{(location + [ key ]).join(".").inspect}"
          end
          node.children.each_slice(2) do |key, value|
            child_location = key.is_a?(Psych::Nodes::Scalar) ? location + [ key.value ] : location
            errors.concat(duplicate_errors(value, path, child_location))
          end
        elsif node.respond_to?(:children)
          Array(node.children).each { |child| errors.concat(duplicate_errors(child, path, location)) }
        end
        errors
      end

      def read_utf8(path)
        path.binread.encode(Encoding::UTF_8)
      end

      def relative(path)
        path.relative_path_from(root).to_s
      end

      def first_line(message)
        message.to_s.lines.first.to_s.strip
      end
    end
  end
end
