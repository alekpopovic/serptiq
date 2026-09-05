# frozen_string_literal: true

require "test_helper"

class CrawlingPageRenderJobTest < ActiveJob::TestCase
  test "routes only to render and delegates exact bounded identifiers" do
    rendered = nil
    concluded = nil
    scan = Struct.new(:status) do
      def terminal? = false
    end.new("running")

    with_public_method(:render_page, ->(**attributes) { rendered = attributes }) do
      with_public_method(:conclude_static_crawl, ->(**attributes) { concluded = attributes; scan }) do
        Crawling::PageRenderJob.perform_now(
          organization_id: SecureRandom.uuid,
          scan_id: SecureRandom.uuid,
          page_render_id: 42
        )
      end
    end

    assert_equal "render", Crawling::PageRenderJob.new.queue_name
    assert_equal 42, rendered.fetch(:page_render_id)
    assert_match(/\Arender-/, rendered.fetch(:worker_id))
    assert_equal rendered.slice(:organization_id, :scan_id), concluded
    assert_equal [ "render" ], Shared::JobTopology.worker(:worker_render).queues.map(&:to_s)
    Shared::JobTopology::WORKERS.except(:worker_render).each_value do |worker|
      refute_includes worker.queues, :render
    end
  end

  private

  def with_public_method(name, replacement)
    original = Crawling::Public.method(name)
    Crawling::Public.define_singleton_method(name, &replacement)
    yield
  ensure
    Crawling::Public.define_singleton_method(name) do |**attributes|
      original.call(**attributes)
    end
  end
end
