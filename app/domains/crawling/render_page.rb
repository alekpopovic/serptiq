# frozen_string_literal: true

require "digest"
require "json"
require "securerandom"
require "stringio"

module Crawling
  class RenderPage
    Claim = Data.define(:render, :token, :usage_source_key)

    def self.usage_source_key(render)
      "page-render:#{render.id}:attempt:#{render.attempts}"
    end

    def initialize(clock: -> { Time.current }, renderer: nil, artifact_capture: nil,
      extractor: HtmlPageExtractor.new, usage_starter: nil, usage_finisher: nil)
      @clock = clock
      @renderer = renderer || FerrumPageRenderer.new
      @artifact_capture = artifact_capture || ->(**attributes) { Public.capture_artifact(**attributes) }
      @extractor = extractor
      @usage_starter = usage_starter || ->(**attributes) { Public.start_usage_operation(**attributes) }
      @usage_finisher = usage_finisher || ->(**attributes) { Public.finish_usage_operation(**attributes) }
    end

    def call(organization_id:, scan_id:, page_render_id:, worker_id:)
      render = exact_render!(organization_id, scan_id, page_render_id)
      claim = claim(render, worker_id)
      return render.reload unless claim

      start_usage(claim)
      usage_started = true
      result = @renderer.call(
        url: claim.render.requested_url,
        screenshot: claim.render.screenshot_enabled,
        canceled: -> { canceled?(claim.render) }
      )
      raise RenderError.new(reason_code: "render_canceled") if canceled?(claim.render)

      dom_artifact = capture(claim, result.dom, kind: "rendered_dom", media_type: "text/html",
        filename: "rendered-page.html")
      screenshot_artifact = if result.screenshot
        capture(claim, result.screenshot, kind: "screenshot", media_type: "image/png",
          filename: "rendered-page.png")
      end
      extraction = extract(claim.render, result)
      complete(claim, result, extraction, dom_artifact.artifact_id, screenshot_artifact&.artifact_id)
    rescue AccessDenied, Shared::Public::SecurityRejectedJobError
      raise
    rescue StandardError => error
      fail_claim(claim, error, usage_started: usage_started) if claim
      Shared::Public.report_observability_failure(error, event_name: "crawler.browser_render")
      claim&.render&.reload
    end

    private

    def exact_render!(organization_id, scan_id, page_render_id)
      PageRender.includes(page_snapshot: %i[fetch_result crawl_url]).find_by!(
        organization_id: organization_id, scan_id: scan_id, id: page_render_id
      )
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied.new(reason_code: "page_render_scope_unavailable"), cause: nil
    end

    def claim(render, worker_id)
      worker = worker_id.to_s
      raise ArgumentError, "page render worker is invalid" unless CrawlUrl::WORKER_PATTERN.match?(worker)

      token = nil
      claimed = nil
      PageRender.transaction do
        scan = Scan.lock.find_by!(organization_id: render.organization_id, id: render.scan_id)
        locked = PageRender.lock.find_by!(organization_id: render.organization_id, scan_id: render.scan_id,
          id: render.id)
        next if locked.terminal?
        now = @clock.call
        next if locked.processing? && locked.lease_expires_at > now
        next if locked.pending? && locked.next_attempt_at > now

        if scan.status.in?(%w[cancel_requested canceled])
          terminalize!(locked, "canceled", "render_canceled")
          next
        end
        if scan.status != "running"
          terminalize!(locked, "skipped", "scan_unavailable")
          next
        end
        if locked.attempts >= locked.maximum_attempts
          terminalize!(locked, "failed", "render_exhausted")
          next
        end

        token = SecureRandom.hex(32)
        locked.update!(
          state: "processing",
          attempts: locked.attempts + 1,
          worker_id: worker,
          lease_token_digest: Digest::SHA256.hexdigest(token),
          started_at: now,
          lease_expires_at: now + browser_lease_duration.seconds,
          next_attempt_at: nil,
          failure_category: nil
        )
        claimed = locked
      end
      Claim.new(claimed, token, self.class.usage_source_key(claimed)) if claimed
    end

    def start_usage(claim)
      @usage_starter.call(
        organization_id: claim.render.organization_id,
        scan_id: claim.render.scan_id,
        source_key: claim.usage_source_key,
        operation_kind: "rendered_page",
        at: @clock.call,
        metadata: { "page_render_id" => claim.render.id, "attempt" => claim.render.attempts }
      )
    end

    def capture(claim, bytes, kind:, media_type:, filename:)
      render = claim.render
      days = Integer(render.scan.settings_snapshot.to_h.stringify_keys.fetch("artifact_retention_days", 1))
      @artifact_capture.call(
        organization_id: render.organization_id,
        project_id: render.project_id,
        property_id: render.property_id,
        environment_id: render.environment_id,
        scan_id: render.scan_id,
        source_type: "page_render",
        source_id: "#{render.id}-#{render.attempts}",
        kind: kind,
        media_type: media_type,
        filename: filename,
        retention_class: "render_evidence",
        retention_expires_at: @clock.call + days.days,
        io: StringIO.new(bytes)
      )
    end

    def extract(render, result)
      scope = Public.url_scope_for_scan(organization_id: render.organization_id, scan_id: render.scan_id)
      @extractor.call(
        body: result.dom,
        document_url: result.final_url,
        scope: scope,
        depth: render.page_snapshot.crawl_url.depth,
        settings: render.scan.settings_snapshot
      )
    end

    def complete(claim, result, extraction, dom_artifact_id, screenshot_artifact_id)
      now = @clock.call
      PageRender.transaction do
        Scan.lock.find_by!(organization_id: claim.render.organization_id, id: claim.render.scan_id)
        render = PageRender.lock.find_by!(organization_id: claim.render.organization_id,
          scan_id: claim.render.scan_id, id: claim.render.id)
        verify_claim!(render, claim.token)
        persist_fact!(render, extraction, now)
        persist_links!(render, extraction.links, now)
        @usage_finisher.call(
          organization_id: render.organization_id,
          scan_id: render.scan_id,
          source_key: claim.usage_source_key,
          outcome: "accepted",
          occurred_at: now,
          at: now,
          metadata: { "page_render_id" => render.id, "attempt" => render.attempts }
        )
        render.update!(
          state: "completed",
          worker_id: nil,
          lease_token_digest: nil,
          started_at: nil,
          lease_expires_at: nil,
          next_attempt_at: nil,
          failure_category: nil,
          finished_at: now,
          final_url: result.final_url,
          final_url_digest: Digest::SHA256.hexdigest(result.final_url),
          rendered_dom_artifact_id: dom_artifact_id,
          screenshot_artifact_id: screenshot_artifact_id,
          rendered_dom_sha256: Digest::SHA256.hexdigest(result.dom),
          renderer_version: result.renderer_version,
          ferrum_version: result.ferrum_version,
          browser_product: result.browser_product,
          browser_revision: result.browser_revision,
          protocol_version: result.protocol_version,
          duration_ms: result.duration_ms,
          request_count: result.request_count,
          response_bytes: result.response_bytes,
          console_messages: result.console_messages,
          page_errors: result.page_errors,
          network_summary: result.network_summary
        )
        emit(render, "succeeded")
        render
      end
    end

    def persist_fact!(render, extraction, now)
      facts = extraction.fact_attributes.deep_stringify_keys
      digest = canonical_digest(facts)
      fact = RenderedPageFact.find_or_initialize_by(page_render_id: render.id)
      if fact.new_record?
        fact.assign_attributes(
          tenant_attributes(render).merge(
            parser_version: extraction.parser_version,
            content_sha256: extraction.content_sha256,
            fact_digest: digest,
            parse_status: extraction.parse_status,
            facts: facts,
            created_at: now,
            updated_at: now
          )
        )
        fact.save!
      elsif fact.fact_digest != digest
        raise Conflict.new(reason_code: "rendered_fact_replay_conflict")
      end
    end

    def persist_links!(render, links, now)
      rows = links.map do |link|
        attributes = tenant_attributes(render).merge(
          destination_url: link.destination_url,
          destination_url_digest: link.destination_url_digest,
          destination_host_digest: link.destination_host_digest,
          normalization_version: link.normalization_version,
          classification: link.classification,
          scope_status: link.scope_status,
          scope_reason: link.scope_reason,
          source_locator: link.source_locator,
          rel_tokens: link.rel_tokens,
          anchor_summary: link.anchor_summary,
          anchor_digest: link.anchor_digest,
          occurrence_count: link.occurrence_count,
          nofollow_count: link.nofollow_count
        )
        attributes.merge(edge_digest: canonical_digest(attributes), created_at: now, updated_at: now)
      end
      RenderedLink.insert_all(rows, unique_by: :index_crawl_rendered_links_on_render_destination) if rows.any?
      existing = RenderedLink.where(page_render_id: render.id).index_by(&:destination_url_digest)
      valid = existing.length == rows.length && rows.all? do |row|
        existing[row.fetch(:destination_url_digest)]&.edge_digest == row.fetch(:edge_digest)
      end
      raise Conflict.new(reason_code: "rendered_link_replay_conflict") unless valid
    end

    def fail_claim(claim, error, usage_started: false)
      now = @clock.call
      PageRender.transaction do
        scan = Scan.lock.find_by!(organization_id: claim.render.organization_id, id: claim.render.scan_id)
        render = PageRender.lock.find_by!(organization_id: claim.render.organization_id,
          scan_id: claim.render.scan_id, id: claim.render.id)
        next unless render.processing? && render.lease_token_matches?(claim.token)

        category = failure_category(error)
        outcome = category == "render_canceled" ? "canceled" : "failed"
        finish_usage(render, claim.usage_source_key, outcome, now) if usage_started
        if outcome == "canceled" || scan.status.in?(%w[cancel_requested canceled])
          terminalize!(render, "canceled", "render_canceled")
        elsif retryable?(render, error, scan)
          render.update!(
            state: "pending",
            worker_id: nil,
            lease_token_digest: nil,
            started_at: nil,
            lease_expires_at: nil,
            next_attempt_at: now + retry_delay(render).seconds,
            failure_category: category
          )
        else
          terminalize!(render, "failed", category)
        end
        emit(render, "failed")
      end
    rescue ActiveRecord::RecordNotFound
      nil
    end

    def finish_usage(render, source_key, outcome, at)
      @usage_finisher.call(
        organization_id: render.organization_id,
        scan_id: render.scan_id,
        source_key: source_key,
        outcome: outcome,
        occurred_at: at,
        at: at,
        metadata: { "page_render_id" => render.id, "attempt" => render.attempts }
      )
    end

    def terminalize!(render, state, category)
      render.update!(
        state: state,
        worker_id: nil,
        lease_token_digest: nil,
        started_at: nil,
        lease_expires_at: nil,
        next_attempt_at: nil,
        failure_category: category,
        finished_at: @clock.call
      )
    end

    def verify_claim!(render, token)
      raise Conflict.new(reason_code: "page_render_lease_lost") unless
        render.processing? && render.lease_token_matches?(token)
    end

    def retryable?(render, error, scan)
      scan.status == "running" && render.attempts < render.maximum_attempts &&
        (!error.respond_to?(:transient?) || error.transient?)
    end

    def failure_category(error)
      value = error.respond_to?(:reason_code) ? error.reason_code.to_s : "render_failed"
      CrawlUrl::FAILURE_PATTERN.match?(value) ? value : "render_failed"
    end

    def retry_delay(render)
      base = Rails.application.config.x.searchops.fetch(:crawler_frontier_retry_base_delay)
      [ base * (2**(render.attempts - 1)), 3600 ].min
    end

    def browser_lease_duration
      Rails.application.config.x.searchops.fetch(:browser_lease_duration)
    end

    def canceled?(render)
      Scan.where(organization_id: render.organization_id, id: render.scan_id,
        status: %w[cancel_requested canceled]).exists?
    end

    def tenant_attributes(render)
      {
        organization_id: render.organization_id,
        project_id: render.project_id,
        property_id: render.property_id,
        environment_id: render.environment_id,
        scan_id: render.scan_id,
        page_render_id: render.id
      }
    end

    def canonical_digest(value)
      Digest::SHA256.hexdigest(JSON.generate(canonical(value)))
    end

    def canonical(value)
      case value
      when Hash
        value.to_h.stringify_keys.sort.to_h { |key, item| [ key, canonical(item) ] }
      when Array
        value.map { |item| canonical(item) }
      else
        value
      end
    end

    def emit(render, outcome)
      Shared::Public.emit_structured_event(
        "crawler.browser_render",
        outcome: outcome,
        reason_code: render.failure_category,
        retry_count: [ render.attempts - 1, 0 ].max,
        duration_ms: render.duration_ms
      )
    rescue ArgumentError => error
      Shared::Public.report_observability_failure(error, event_name: "crawler.browser_render")
    end
  end
end
