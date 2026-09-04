require "test_helper"

class ApplicationBaselineTest < ActiveSupport::TestCase
  test "uses the pinned Rails release and PostgreSQL adapter" do
    assert_equal "8.1.3.1", Rails.version
    assert_equal "postgresql", ActiveRecord::Base.connection_db_config.adapter
  end

  test "includes the Rails Solid stack without forbidden infrastructure gems" do
    bundled_gems = Bundler.load.specs.map(&:name)

    assert_includes bundled_gems, "solid_cache"
    assert_includes bundled_gems, "solid_queue"
    assert_includes bundled_gems, "solid_cable"

    %w[devise doorkeeper elasticsearch omniauth redis sidekiq sqlite3].each do |gem_name|
      refute_includes bundled_gems, gem_name
    end
  end
end
