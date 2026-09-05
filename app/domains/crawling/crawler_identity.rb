# frozen_string_literal: true

module Crawling
  module CrawlerIdentity
    PRODUCT_TOKEN = "SearchOpsBot"
    VERSION = "1.0"
    BASE = "#{PRODUCT_TOKEN}/#{VERSION}".freeze
    CONTACT_PATH = "/crawler"
    USER_AGENT_PATTERN = /\A[A-Za-z0-9][A-Za-z0-9._+\-\/:(); ]{0,254}\z/

    module_function

    def http_user_agent(contact_url: default_contact_url)
      contact = contact_url.to_s
      value = "#{BASE} (+#{contact})"
      raise ArgumentError, "crawler contact URL is invalid" unless
        contact.start_with?("http://", "https://") && !contact.match?(/[\u0000-\u0020\u007f]/) &&
          value.bytesize <= 256 && USER_AGENT_PATTERN.match?(value)

      value.freeze
    end

    def default_contact_url
      origin = Rails.application.config.x.searchops.fetch(:application_origin).to_s.delete_suffix("/")
      "#{origin}#{CONTACT_PATH}".freeze
    end
  end
end
