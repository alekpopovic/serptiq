require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Searchops
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Tenant and externally referenced aggregate roots default to UUIDs. High-
    # volume internal rows opt into bigint explicitly; see DATABASES.md.
    config.generators do |generators|
      generators.orm :active_record, primary_key_type: :uuid
    end

    # PostgreSQL-backed Rails runtime services are configured consistently in
    # every environment. Tests may replace individual adapters explicitly.
    config.active_job.queue_adapter = :solid_queue
    config.solid_queue.connects_to = { database: { writing: :queue } }
    config.solid_queue.use_skip_locked = true
    config.solid_queue.process_heartbeat_interval = 30.seconds
    config.solid_queue.process_alive_threshold = 3.minutes
    config.solid_queue.fork_boot_timeout = 2.minutes
    config.solid_queue.shutdown_timeout = 30.seconds
    config.solid_queue.preserve_finished_jobs = true
    config.solid_queue.clear_finished_jobs_after = 24.hours
    config.solid_queue.default_concurrency_control_period = 5.minutes
    config.cache_store = :solid_cache_store
    config.action_mailer.deliver_later_queue_name = :mail

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
