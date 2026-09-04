# frozen_string_literal: true

require "test_helper"

Selenium::WebDriver.logger.level = :warn
Capybara.save_path = Rails.root.join("tmp/system-test-artifacts")
ENV["RAILS_SYSTEM_TESTING_SCREENSHOT_HTML"] ||= "1"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ] do |options|
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_option("goog:loggingPrefs", { browser: "ALL" })
  end

  setup { Authorization::Public.sync_catalog }

  def take_failed_screenshot
    capture_browser_console if failed? && Capybara::Session.instance_created?
    super
  end

  private

  def capture_browser_console
    entries = page.driver.browser.logs.get(:browser)
    lines = entries.map { |entry| "#{entry.level} #{entry.timestamp} #{entry.message}" }
    lines = [ "No browser console entries were recorded." ] if lines.empty?
    path = Pathname(Capybara.save_path)
    path.mkpath
    path.join("failures_#{method_name.gsub(/[^\w]+/, "-")}.console.log").write("#{lines.join("\n")}\n")
  rescue StandardError => error
    warn "Unable to capture browser console: #{error.class}: #{error.message}"
  end
end
