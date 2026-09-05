# frozen_string_literal: true

require "addressable/uri"
require "digest"
require "json"
require "nokogiri"

module Crawling
  class HtmlPageExtractor
    PARSER_VERSION = "html5-facts-1.0"
    MAX_HTML_BYTES = 5.megabytes
    MAX_ELEMENTS = 50_000
    MAX_ATTRIBUTES_PER_ELEMENT = 128
    MAX_TREE_DEPTH = 256
    MAX_PARSE_ERRORS = 20
    MAX_ATTRIBUTE_BYTES = 8192
    MAX_LINKS = 5000
    MAX_META_DIRECTIVES = 100
    MAX_HEADINGS = 200
    MAX_CANONICALS = 20
    MAX_HREFLANGS = 100
    MAX_IMAGES = 500
    MAX_STRUCTURED_DATA_BLOCKS = 20
    MAX_STRUCTURED_DATA_BYTES = 32.kilobytes
    MAX_STRUCTURED_DATA_TOTAL_BYTES = 256.kilobytes
    FACT_KEYS = PageFact::FACT_KEYS
    ROBOTS_NAMES = %w[robots googlebot bingbot searchopsbot].freeze

    LinkOccurrence = Data.define(
      :normalized, :classification, :scope_status, :scope_reason,
      :source_locator, :rel_tokens, :anchor_summary, :anchor_digest, :nofollow
    )

    def initialize(normalizer: UrlNormalizer.new)
      @normalizer = normalizer
    end

    def call(body:, document_url:, scope:, depth:, settings: {})
      bytes = body.to_s.b
      raise extraction_error("extraction_body_too_large") if bytes.bytesize > MAX_HTML_BYTES

      settings = settings.to_h.stringify_keys
      document = parse(bytes)
      element_count = count_elements!(document)
      base = extract_base(document, document_url, settings)
      effective_base = base.fetch(:url) || document_url
      title = extract_scalar(document.at_css("title"), 512)
      description = extract_description(document)
      language = extract_language(document)
      meta_directives = extract_meta_directives(document)
      headings = extract_headings(document)
      canonicals = extract_url_facts(
        document.css("link[rel][href]").select { |node| rel_tokens(node).include?("canonical") }
          .first(MAX_CANONICALS),
        effective_base,
        settings
      )
      hreflangs = extract_hreflangs(document, effective_base, settings)
      images = extract_images(document, effective_base, scope, depth, settings)
      structured_data = extract_structured_data(document)
      links, link_counts = extract_links(document, effective_base, scope, depth, settings)
      facts = {
        "base" => base.fetch(:status),
        "title" => title.fetch(:status),
        "description" => description.fetch(:status),
        "language" => language.fetch(:status),
        "meta_directives" => collection_status(meta_directives),
        "headings" => collection_status(headings),
        "canonical" => collection_status(canonicals),
        "hreflang" => collection_status(hreflangs),
        "images" => collection_status(images),
        "structured_data" => collection_status(structured_data)
      }.freeze
      counts = {
        "elements" => element_count,
        "meta_directives" => meta_directives.length,
        "headings" => headings.length,
        "canonicals" => canonicals.length,
        "hreflangs" => hreflangs.length,
        "images" => images.length,
        "structured_data_blocks" => structured_data.length
      }.merge(link_counts).freeze

      HtmlExtractionResult.new(
        parser_version: PARSER_VERSION,
        content_sha256: Digest::SHA256.hexdigest(bytes),
        parse_status: document.errors.any? ? "malformed" : "parsed",
        parse_error_count: [ document.errors.length, MAX_PARSE_ERRORS ].min,
        element_count: element_count,
        effective_base_url: effective_base,
        title_status: title.fetch(:status),
        title_summary: title[:summary],
        title_digest: title[:digest],
        description_status: description.fetch(:status),
        description_summary: description[:summary],
        description_digest: description[:digest],
        language_status: language.fetch(:status),
        document_language: language[:summary],
        fact_statuses: facts,
        meta_directives: meta_directives.freeze,
        headings: headings.freeze,
        canonicals: canonicals.freeze,
        hreflangs: hreflangs.freeze,
        images: images.freeze,
        structured_data_blocks: structured_data.freeze,
        counts: counts,
        links: links.freeze
      )
    rescue Nokogiri::SyntaxError => error
      raise extraction_error("html_parse_failed"), cause: error
    end

    private

    def parse(bytes)
      Nokogiri::HTML5.parse(
        bytes,
        max_errors: MAX_PARSE_ERRORS,
        max_tree_depth: MAX_TREE_DEPTH,
        max_attributes: MAX_ATTRIBUTES_PER_ELEMENT
      )
    end

    def count_elements!(document)
      count = 0
      document.traverse do |node|
        next unless node.element?

        count += 1
        raise extraction_error("html_element_limit_exceeded") if count > MAX_ELEMENTS
      end
      count
    end

    def extract_base(document, document_url, settings)
      node = document.at_css("base[href]")
      return { status: "absent", url: nil }.freeze unless node

      normalized = normalize_reference(document_url, node["href"], settings)
      if normalized
        { status: "present", url: normalized.fetch_url }.freeze
      else
        { status: "malformed", url: nil }.freeze
      end
    end

    def extract_scalar(node, maximum_bytes)
      return { status: "absent", summary: nil, digest: nil }.freeze unless node

      full = EvidenceSnippet.call(node.text, maximum_bytes: maximum_bytes * 4)
      return { status: "malformed", summary: nil, digest: Digest::SHA256.hexdigest("") }.freeze if full.blank?

      {
        status: "present",
        summary: EvidenceSnippet.call(full, maximum_bytes: maximum_bytes),
        digest: Digest::SHA256.hexdigest(full)
      }.freeze
    end

    def extract_description(document)
      node = document.css("meta[name]").find { |candidate| candidate["name"].to_s.casecmp?("description") }
      return { status: "absent", summary: nil, digest: nil }.freeze unless node

      attribute_scalar(node, "content", 1024)
    end

    def extract_language(document)
      html = document.at_css("html")
      declared = bounded_attribute(html, "lang") if html
      if declared.blank?
        meta = document.css("meta[http-equiv]").find do |candidate|
          candidate["http-equiv"].to_s.casecmp?("content-language")
        end
        declared = bounded_attribute(meta, "content") if meta
      end
      return { status: "absent", summary: nil }.freeze if declared.blank?

      value = EvidenceSnippet.call(declared, maximum_bytes: 64)
      status = value.match?(/\A[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*\z/) ? "present" : "malformed"
      { status: status, summary: value }.freeze
    end

    def extract_meta_directives(document)
      document.css("meta").filter_map do |node|
        name = bounded_attribute(node, "name")&.downcase
        http_equiv = bounded_attribute(node, "http-equiv")&.downcase
        key = name.presence || http_equiv.presence
        next unless key && (ROBOTS_NAMES.include?(key) || key.in?(%w[viewport content-language refresh]))

        content = bounded_attribute(node, "content")
        {
          "name" => key,
          "status" => content.nil? ? "malformed" : "present",
          "content_summary" => content && EvidenceSnippet.call(content, maximum_bytes: 1024),
          "tokens" => directive_tokens(key, content),
          "source_locator" => locator(node)
        }
      end.first(MAX_META_DIRECTIVES)
    end

    def directive_tokens(name, content)
      return [] unless ROBOTS_NAMES.include?(name)

      content.to_s.downcase.split(/[\s,]+/).filter_map do |token|
        clean = token.gsub(/[^a-z0-9:_-]/, "")
        clean.presence if clean.bytesize <= 64
      end.uniq.sort.first(50)
    end

    def extract_headings(document)
      document.css("h1, h2, h3, h4, h5, h6").first(MAX_HEADINGS).map do |node|
        text = EvidenceSnippet.call(node.text, maximum_bytes: 2048)
        {
          "level" => node.name.delete_prefix("h").to_i,
          "status" => text.present? ? "present" : "malformed",
          "text_summary" => text.present? ? EvidenceSnippet.call(text, maximum_bytes: 512) : nil,
          "text_digest" => Digest::SHA256.hexdigest(text),
          "source_locator" => locator(node)
        }
      end
    end

    def extract_url_facts(nodes, base_url, settings)
      nodes.map do |node|
        raw = bounded_attribute(node, "href")
        normalized = normalize_reference(base_url, raw, settings) if raw
        {
          "status" => normalized ? "present" : "malformed",
          "url" => normalized&.identity_url,
          "url_digest" => normalized&.identity_digest,
          "value_digest" => Digest::SHA256.hexdigest(raw.to_s),
          "source_locator" => locator(node)
        }
      end
    end

    def extract_hreflangs(document, base_url, settings)
      nodes = document.css("link[rel][href][hreflang]").select do |node|
        rel_tokens(node).include?("alternate")
      end.first(MAX_HREFLANGS)
      nodes.map do |node|
        raw = bounded_attribute(node, "href")
        language = bounded_attribute(node, "hreflang")
        normalized = normalize_reference(base_url, raw, settings) if raw
        valid_language = language.present? && language.bytesize <= 64
        {
          "status" => normalized && valid_language ? "present" : "malformed",
          "language" => valid_language ? EvidenceSnippet.call(language.downcase, maximum_bytes: 64) : nil,
          "url" => normalized&.identity_url,
          "url_digest" => normalized&.identity_digest,
          "value_digest" => Digest::SHA256.hexdigest(raw.to_s),
          "source_locator" => locator(node)
        }
      end
    end

    def extract_images(document, base_url, scope, depth, settings)
      document.css("img").first(MAX_IMAGES).map do |node|
        raw = bounded_attribute(node, "src")
        normalized = normalize_reference(base_url, raw, settings) if raw
        alt_attribute = node.attribute("alt")
        alt_present = !alt_attribute.nil?
        alt = bounded_attribute(node, "alt")
        decision = normalized && scope.evaluate(url: normalized.fetch_url, depth: depth)
        {
          "status" => normalized ? "present" : "malformed",
          "url" => normalized&.identity_url,
          "url_digest" => normalized&.identity_digest,
          "internal" => internal_destination?(normalized, scope),
          "scope_status" => decision&.allowed? ? "allowed" : "denied",
          "alt_status" => image_alt_status(alt_attribute, alt),
          "alt_summary" => alt.present? ? EvidenceSnippet.call(alt, maximum_bytes: 512) : nil,
          "alt_digest" => alt_present ? Digest::SHA256.hexdigest(alt.to_s) : nil,
          "width" => bounded_dimension(node["width"]),
          "height" => bounded_dimension(node["height"]),
          "loading" => bounded_attribute(node, "loading")&.downcase,
          "source_locator" => locator(node)
        }
      end
    end

    def image_alt_status(attribute, bounded_value)
      return "absent" unless attribute
      return "malformed" if attribute.to_s.bytesize > MAX_ATTRIBUTE_BYTES

      bounded_value.present? ? "present" : "empty"
    end

    def extract_structured_data(document)
      total = 0
      document.css("script[type]").filter_map do |node|
        next unless node["type"].to_s.split(";", 2).first.to_s.strip.casecmp?("application/ld+json")

        raw = node.text.to_s
        digest = Digest::SHA256.hexdigest(raw)
        entry = if raw.bytesize > MAX_STRUCTURED_DATA_BYTES ||
            total + raw.bytesize > MAX_STRUCTURED_DATA_TOTAL_BYTES
          { "status" => "too_large", "content_digest" => digest }
        else
          total += raw.bytesize
          parse_structured_data(raw, digest)
        end
        entry.merge("source_locator" => locator(node))
      end.first(MAX_STRUCTURED_DATA_BLOCKS)
    end

    def parse_structured_data(raw, digest)
      data = JSON.parse(raw, max_nesting: 64)
      unless data.is_a?(Hash) || data.is_a?(Array)
        return { "status" => "malformed", "content_digest" => digest }
      end

      { "status" => "present", "content_digest" => digest, "data" => data }
    rescue JSON::ParserError, JSON::NestingError
      { "status" => "malformed", "content_digest" => digest }
    end

    def extract_links(document, base_url, scope, depth, settings)
      occurrences = []
      invalid = 0
      nodes = document.css("a[href], area[href]").first(MAX_LINKS)
      nodes.each do |node|
        raw = bounded_attribute(node, "href")
        normalized = normalize_reference(base_url, raw, settings) if raw
        unless normalized
          invalid += 1
          next
        end

        decision = scope.evaluate(url: normalized.fetch_url, depth: depth + 1)
        internal = internal_destination?(normalized, scope)
        relations = rel_tokens(node)
        anchor = accessible_anchor(node)
        occurrences << LinkOccurrence.new(
          normalized: normalized,
          classification: internal ? "internal" : "external",
          scope_status: decision.allowed? ? "allowed" : "denied",
          scope_reason: decision.reason_code,
          source_locator: locator(node),
          rel_tokens: relations,
          anchor_summary: anchor[:summary],
          anchor_digest: anchor.fetch(:digest),
          nofollow: relations.include?("nofollow")
        )
      end
      links = aggregate_links(occurrences)
      counts = {
        "link_elements_inspected" => nodes.length,
        "link_edges" => links.length,
        "invalid_links" => invalid,
        "internal_link_edges" => links.count(&:internal?),
        "external_link_edges" => links.count { |link| !link.internal? }
      }
      [ links, counts ]
    end

    def aggregate_links(occurrences)
      occurrences.group_by { |item| item.normalized.identity_digest }.values.map do |group|
        first = group.first
        anchors = group.map(&:anchor_digest).sort.join(":")
        HtmlLinkObservation.new(
          destination_url: first.normalized.identity_url,
          destination_url_digest: first.normalized.identity_digest,
          destination_host_digest: first.normalized.host_digest,
          normalization_version: first.normalized.normalization_version,
          classification: first.classification,
          scope_status: first.scope_status,
          scope_reason: first.scope_reason,
          source_locator: first.source_locator,
          rel_tokens: group.flat_map(&:rel_tokens).uniq.sort.first(20),
          anchor_summary: group.filter_map(&:anchor_summary).first,
          anchor_digest: Digest::SHA256.hexdigest(anchors),
          occurrence_count: group.length,
          nofollow_count: group.count(&:nofollow)
        )
      end
    end

    def normalize_reference(base_url, raw, settings)
      return if raw.blank? || raw.bytesize > MAX_ATTRIBUTE_BYTES

      absolute = Addressable::URI.join(base_url, raw).to_s
      @normalizer.call(
        url: absolute,
        query_handling: settings.fetch("query_handling", "all"),
        query_parameter_allowlist: settings.fetch("query_parameter_allowlist", []),
        query_parameter_denylist: settings.fetch("query_parameter_denylist", [])
      )
    rescue Addressable::URI::InvalidURIError, ArgumentError, TypeError
      nil
    end

    def internal_destination?(normalized, scope)
      return false unless normalized

      normalized.scheme == scope.origin.scheme && normalized.port == scope.origin.port &&
        (normalized.host == scope.origin.host || scope.allowed_hosts.include?(normalized.host))
    end

    def accessible_anchor(node)
      candidates = [ node.text, node["aria-label"], node["title"] ]
      candidates.concat(node.css("img[alt]").map { |image| image["alt"] })
      full = candidates.filter_map do |candidate|
        value = EvidenceSnippet.call(candidate, maximum_bytes: 2048)
        value if value.present?
      end.first.to_s
      {
        summary: full.present? ? EvidenceSnippet.call(full, maximum_bytes: 512) : nil,
        digest: Digest::SHA256.hexdigest(full)
      }.freeze
    end

    def attribute_scalar(node, name, maximum_bytes)
      value = bounded_attribute(node, name)
      return { status: "malformed", summary: nil, digest: Digest::SHA256.hexdigest("") }.freeze if value.blank?

      full = EvidenceSnippet.call(value, maximum_bytes: maximum_bytes * 4)
      {
        status: "present",
        summary: EvidenceSnippet.call(full, maximum_bytes: maximum_bytes),
        digest: Digest::SHA256.hexdigest(full)
      }.freeze
    end

    def bounded_attribute(node, name)
      value = node&.[](name)&.to_s
      return if value.nil? || !value.valid_encoding? || value.bytesize > MAX_ATTRIBUTE_BYTES

      value
    end

    def bounded_dimension(value)
      number = Integer(value.to_s, exception: false)
      number if number&.between?(1, 100_000)
    end

    def rel_tokens(node)
      bounded_attribute(node, "rel").to_s.downcase.split(/\s+/).filter_map do |token|
        token if token.match?(/\A[a-z][a-z0-9_-]{0,63}\z/)
      end.uniq.sort.first(20)
    end

    def locator(node)
      EvidenceSnippet.call(node.path, maximum_bytes: 512).presence || "/unknown"
    end

    def collection_status(values)
      return "absent" if values.empty?
      return "malformed" if values.any? { |value| value["status"].in?(%w[malformed too_large]) }

      "present"
    end

    def extraction_error(reason_code)
      Invalid.new(field_errors: { html: "HTML cannot be extracted safely." }, reason_code: reason_code)
    end
  end
end
