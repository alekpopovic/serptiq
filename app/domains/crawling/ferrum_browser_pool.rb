# frozen_string_literal: true

require "ferrum"

module Crawling
  class FerrumBrowserPool
    FERRUM_VERSION = Gem.loaded_specs.fetch("ferrum").version.to_s.freeze

    def initialize(settings: Rails.application.config.x.searchops, browser_factory: nil,
      browser_options: {})
      @settings = settings
      @browser_factory = browser_factory || method(:build_browser)
      @browser_options = browser_options
      @mutex = Mutex.new
    end

    def with_page(&block)
      @mutex.synchronize do
        browser.create_page(new_context: true, &block)
      rescue Ferrum::DeadBrowserError, Ferrum::ProcessTimeoutError, Errno::EPIPE
        recycle
        raise
      end
    end

    def browser_provenance
      process = browser.process
      {
        browser_product: process.browser_version.to_s,
        browser_revision: browser.command("Browser.getVersion").fetch("revision").to_s,
        protocol_version: process.protocol_version.to_s
      }.freeze
    end

    def recycle
      @browser&.quit
    rescue Ferrum::Error, IOError, SystemCallError
      nil
    ensure
      @browser = nil
    end

    private

    def browser
      @browser ||= @browser_factory.call
    end

    def build_browser
      Ferrum::Browser.new(
        browser_path: Rails.root.join("bin/searchops-chromium").to_s,
        headless: true,
        incognito: true,
        dockerize: false,
        timeout: @settings.fetch(:browser_timeout),
        protocol_timeout: [ @settings.fetch(:browser_timeout), 10 ].min,
        process_timeout: 15,
        ws_max_receive_size: 16.megabytes,
        pending_connection_errors: true,
        browser_options: {
          "disable-background-networking" => nil,
          "disable-breakpad" => nil,
          "disable-component-update" => nil,
          "disable-default-apps" => nil,
          "disable-dev-shm-usage" => nil,
          "disable-extensions" => nil,
          "disable-features" => "Translate,MediaRouter,OptimizationHints",
          "disable-gpu" => nil,
          "disable-sync" => nil,
          "metrics-recording-only" => nil,
          "no-first-run" => nil,
          "safebrowsing-disable-auto-update" => nil
        }.merge(@browser_options)
      )
    end
  end
end
