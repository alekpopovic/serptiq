# frozen_string_literal: true

require "nokogiri"

module Crawling
  class SitemapParser
    VERSION = 1
    NAMESPACE = "http://www.sitemaps.org/schemas/sitemap/0.9"
    MAXIMUM_FIELD_BYTES = 8192
    MAXIMUM_LASTMOD_BYTES = 64
    MAXIMUM_WARNINGS = 1000
    TEXT_NODE_TYPES = [
      Nokogiri::XML::Reader::TYPE_TEXT,
      Nokogiri::XML::Reader::TYPE_CDATA,
      Nokogiri::XML::Reader::TYPE_SIGNIFICANT_WHITESPACE
    ].freeze
    FORBIDDEN_NODE_TYPES = [
      Nokogiri::XML::Reader::TYPE_DOCUMENT_TYPE,
      Nokogiri::XML::Reader::TYPE_ENTITY,
      Nokogiri::XML::Reader::TYPE_ENTITY_REFERENCE,
      Nokogiri::XML::Reader::TYPE_END_ENTITY,
      Nokogiri::XML::Reader::TYPE_NOTATION
    ].freeze
    OPTIONS = Nokogiri::XML::ParseOptions::STRICT | Nokogiri::XML::ParseOptions::NONET

    def initialize(max_entries:, max_depth:)
      @max_entries = Integer(max_entries)
      @max_depth = Integer(max_depth)
      raise ArgumentError, "sitemap parser limits are invalid" unless
        @max_entries.between?(1, 50_000) && @max_depth.between?(4, 128)
    end

    def call(xml:)
      state = initial_state
      reader = Nokogiri::XML::Reader(xml.to_s.b, nil, "UTF-8", OPTIONS)
      reader.each { |node| consume(node, state) }
      finish(state)
    rescue Nokogiri::XML::SyntaxError
      warning!(state, "malformed_xml")
      finish(state, malformed: true)
    rescue ParserRejection => error
      warning!(state, error.reason_code)
      finish(state, malformed: true)
    end

    private

    ParserRejection = Class.new(StandardError) do
      attr_reader :reason_code

      def initialize(reason_code)
        @reason_code = reason_code
        super(reason_code)
      end
    end

    def initial_state
      {
        kind: "unknown", entries: [], warnings: [], root_seen: false,
        active_entry: nil, active_field: nil, field_value: +"".b, entry_count: 0
      }
    end

    def consume(node, state)
      raise ParserRejection, "forbidden_xml_construct" if FORBIDDEN_NODE_TYPES.include?(node.node_type)
      raise ParserRejection, "xml_depth_limit" if node.depth > @max_depth

      case node.node_type
      when Nokogiri::XML::Reader::TYPE_ELEMENT
        consume_start(node, state)
      when Nokogiri::XML::Reader::TYPE_END_ELEMENT
        consume_end(node, state)
      else
        consume_text(node, state) if TEXT_NODE_TYPES.include?(node.node_type)
      end
    end

    def consume_start(node, state)
      unless state[:root_seen]
        state[:root_seen] = true
        state[:kind] = root_kind(node)
        warning!(state, "namespace_missing_or_invalid") unless node.namespace_uri == NAMESPACE
        return
      end

      entry_name = state[:kind] == "urlset" ? "url" : "sitemap"
      if node.depth == 1 && node.local_name == entry_name
        state[:entry_count] += 1
        raise ParserRejection, "entry_limit" if state[:entry_count] > @max_entries

        state[:active_entry] = { location: nil, lastmod: nil, index: state[:entry_count] }
        finish_entry(state) if node.empty_element?
      elsif state[:active_entry] && node.depth == 2 && %w[loc lastmod].include?(node.local_name)
        state[:active_field] = node.local_name
        state[:field_value] = +"".b
        finish_field(state) if node.empty_element?
      end
    end

    def consume_text(node, state)
      return unless state[:active_field]

      value = node.value.to_s
      limit = state[:active_field] == "lastmod" ? MAXIMUM_LASTMOD_BYTES : MAXIMUM_FIELD_BYTES
      raise ParserRejection, "field_size_limit" if state[:field_value].bytesize + value.bytesize > limit

      state[:field_value] << value
    end

    def consume_end(node, state)
      if node.depth == 2 && node.local_name == state[:active_field]
        finish_field(state)
      elsif node.depth == 1 && state[:active_entry]
        expected = state[:kind] == "urlset" ? "url" : "sitemap"
        finish_entry(state) if node.local_name == expected
      end
    end

    def root_kind(node)
      return "urlset" if node.depth.zero? && node.local_name == "urlset"
      return "sitemap_index" if node.depth.zero? && node.local_name == "sitemapindex"

      raise ParserRejection, "unsupported_root"
    end

    def finish_field(state)
      value = state[:field_value].force_encoding(Encoding::UTF_8)
      raise ParserRejection, "invalid_utf8" unless value.valid_encoding?

      key = state[:active_field] == "loc" ? :location : :lastmod
      state[:active_entry][key] = value.strip.presence
      state[:active_field] = nil
      state[:field_value] = +"".b
    end

    def finish_entry(state)
      entry = state[:active_entry]
      kind = state[:kind] == "urlset" ? "page" : "sitemap"
      if entry[:location].nil?
        warning!(state, "location_missing", entry[:index])
      else
        state[:entries] << SitemapParsedEntry.new(
          kind: kind,
          location: entry[:location],
          lastmod: entry[:lastmod],
          entry_index: entry[:index]
        )
      end
      state[:active_entry] = nil
      state[:active_field] = nil
      state[:field_value] = +"".b
    end

    def warning!(state, code, entry_index = nil)
      return unless state && state[:warnings].length < MAXIMUM_WARNINGS

      state[:warnings] << SitemapWarning.new(code: code, entry_index: entry_index)
    end

    def finish(state, malformed: false)
      malformed ||= !state[:root_seen] || state[:kind] == "unknown"
      warning!(state, "empty_document") unless state[:root_seen]
      ParsedSitemap.new(
        kind: state[:kind], entries: state[:entries], warnings: state[:warnings],
        parser_version: VERSION, malformed: malformed
      )
    end
  end
end
