# frozen_string_literal: true

require "date"
require "pathname"

module Searchops
  module Documentation
    class AdrIndexChecker
      STATUSES = %w[Proposed Accepted Superseded Rejected Deprecated].freeze
      REQUIRED_TEMPLATE_HEADINGS = [
        "Context",
        "Decision",
        "Alternatives",
        "Security/Privacy",
        "Operations",
        "Consequences",
        "Revisit Triggers"
      ].freeze

      def initialize(directory:)
        @directory = Pathname(directory).expand_path
      end

      def errors
        return [ "missing ADR directory #{@directory}" ] unless @directory.directory?

        errors = []
        files = adr_files
        links = index_links(errors)
        file_ids = files.map { |file| adr_id(file) }

        duplicate_links = links.group_by(&:first).select { |_id, entries| entries.size > 1 }.keys
        errors << "duplicate index ADRs: #{duplicate_links.join(', ')}" unless duplicate_links.empty?

        linked_ids = links.map(&:first).uniq
        missing_from_index = file_ids - linked_ids
        extra_in_index = linked_ids - file_ids
        errors << "ADR files missing from index: #{missing_from_index.join(', ')}" unless missing_from_index.empty?
        errors << "index references unknown ADRs: #{extra_in_index.join(', ')}" unless extra_in_index.empty?

        links.each { |id, target| validate_link(id, target, errors) }
        files.each { |file| validate_adr(file, errors) }
        validate_template(errors)
        errors
      end

      private

      def adr_files
        @directory.glob("[0-9][0-9][0-9][0-9]_*.md").sort
      end

      def adr_id(file)
        file.basename.to_s.split("_", 2).first
      end

      def index_links(errors)
        index = @directory.join("README.md")
        unless index.file?
          errors << "missing ADR index #{index}"
          return []
        end

        index.read.scan(/\[(\d{4})(?:[^\]]*)\]\(([^)#]+)(?:#[^)]*)?\)/)
      end

      def validate_link(id, target, errors)
        path = @directory.join(target).cleanpath
        errors << "ADR #{id} link does not resolve: #{target}" unless path.file?
        errors << "ADR #{id} link target ID mismatch: #{target}" unless path.basename.to_s.start_with?("#{id}_")
      end

      def validate_adr(file, errors)
        id = adr_id(file)
        content = file.read
        errors << "ADR #{id} heading does not match filename" unless content.match?(/\A# ADR #{id} — .+/)

        status = metadata(content, "Status")
        errors << "ADR #{id} has invalid or missing status" unless STATUSES.include?(status)
        errors << "ADR #{id} is missing Date" unless iso8601_date?(metadata(content, "Date"))
        errors << "ADR #{id} is missing Owners" if metadata(content, "Owners").to_s.empty?

        last_reviewed = metadata(content, "Last reviewed").to_s.split.first
        errors << "ADR #{id} is missing Last reviewed" unless iso8601_date?(last_reviewed)
      end

      def validate_template(errors)
        template = @directory.join("ADR_TEMPLATE.md")
        unless template.file?
          errors << "missing ADR template #{template}"
          return
        end

        content = template.read
        REQUIRED_TEMPLATE_HEADINGS.each do |heading|
          errors << "ADR template is missing #{heading}" unless content.include?("## #{heading}\n")
        end
        [ "Owners", "Reviewers", "Last reviewed", "Supersedes", "Superseded by" ].each do |label|
          errors << "ADR template is missing #{label}" unless content.match?(/^- #{Regexp.escape(label)}:/)
        end
      end

      def metadata(content, key)
        content[/^- #{Regexp.escape(key)}:\s*(.+)$/, 1]&.strip
      end

      def iso8601_date?(value)
        Date.iso8601(value.to_s)
        true
      rescue Date::Error
        false
      end
    end
  end
end
