#!/usr/bin/env ruby
# frozen_string_literal: true

require "csv"
require "digest"
require "fileutils"
require "json"
require "optparse"
require "time"

class TrackerError < StandardError; end

class PromptTracker
  VALID_STATUSES = %w[pending in_progress blocked completed].freeze
  TEST_OUTCOMES = %w[passed failed not_run].freeze

  attr_reader :root, :catalog_path, :state_path

  def initialize(root)
    @root = File.expand_path(root)
    @catalog_path = File.join(@root, "tracking", "prompt_catalog.csv")
    @state_path = File.join(@root, "tracking", "state.json")
    @lock_path = File.join(@root, "tracking", ".state.lock")
    @results_dir = File.join(@root, "tracking", "results")
    @archive_dir = File.join(@results_dir, "archive")
    @jsonl_path = File.join(@root, "tracking", "execution_log.jsonl")
    @markdown_log_path = File.join(@root, "tracking", "EXECUTION_LOG.md")
    @blockers_path = File.join(@root, "tracking", "BLOCKERS.md")
    @catalog = load_catalog
    validate_catalog!
  end

  def validate!
    state = load_state
    errors = validate_state(state)
    if errors.empty?
      puts "VALID: #{@catalog.length} prompts; catalog and state are consistent."
      true
    else
      errors.each { |error| warn "ERROR: #{error}" }
      raise TrackerError, "validation failed with #{errors.length} error(s)"
    end
  end

  def status(json: false)
    state = load_state
    errors = validate_state(state)
    raise TrackerError, errors.join("; ") unless errors.empty?

    counts = VALID_STATUSES.to_h { |status| [status, 0] }
    state.fetch("prompts").each_value { |entry| counts[entry.fetch("status")] += 1 }
    current = state["current_prompt"]
    next_entry = eligible_prompt(state)
    payload = {
      project: state["project"],
      total: @catalog.length,
      counts: counts,
      current_prompt: current && prompt_summary(current, state),
      next_prompt: next_entry && prompt_summary(next_entry.fetch("id"), state),
      blocked: state.fetch("prompts").filter_map do |id, entry|
        next unless entry.fetch("status") == "blocked"
        prompt_summary(id, state).merge(block_reason: entry["block_reason"])
      end,
      updated_at: state["updated_at"]
    }

    if json
      puts JSON.pretty_generate(payload)
    else
      puts "Project: #{payload[:project]}"
      puts "Progress: #{counts["completed"]}/#{@catalog.length} completed"
      puts VALID_STATUSES.map { |key| "#{key}=#{counts[key]}" }.join("  ")
      if current
        item = payload[:current_prompt]
        puts "Current: #{item[:id]} — #{item[:title]} (#{item[:reasoning]})"
      elsif next_entry
        item = payload[:next_prompt]
        puts "Next: #{item[:id]} — #{item[:title]} (#{item[:reasoning]})"
      else
        puts(counts["completed"] == @catalog.length ? "All prompts are completed." : "No prompt is currently eligible.")
      end
      unless payload[:blocked].empty?
        puts "Blocked:"
        payload[:blocked].each do |item|
          puts "  #{item[:id]} — #{item[:title]}: #{item[:block_reason]}"
        end
      end
    end
  end

  def next_prompt(json: false)
    state = load_state
    errors = validate_state(state)
    raise TrackerError, errors.join("; ") unless errors.empty?

    if state["current_prompt"]
      id = state.fetch("current_prompt")
      item = prompt_summary(id, state)
      item[:message] = "A prompt is already in progress."
    else
      row = eligible_prompt(state)
      if row
        item = prompt_summary(row.fetch("id"), state)
        item[:message] = "Eligible prompt."
      elsif state.fetch("prompts").values.all? { |entry| entry.fetch("status") == "completed" }
        item = { message: "All prompts are completed." }
      else
        blockers = blocking_frontier(state)
        item = {
          message: "No prompt is eligible because unresolved blockers or incomplete dependencies remain.",
          blockers: blockers
        }
      end
    end

    if json
      puts JSON.pretty_generate(item)
    else
      if item[:id]
        puts "#{item[:id]} — #{item[:title]}"
        puts "File: #{item[:filename]}"
        puts "Reasoning: #{item[:reasoning]}"
        puts "Dependencies: #{item[:depends_on].empty? ? "none" : item[:depends_on].join(", ")}"
        puts item[:message]
      else
        puts item[:message]
        Array(item[:blockers]).each { |b| puts "  #{b[:id]} — #{b[:reason]}" }
      end
    end
  end

  def show(id, json: false)
    state = load_state
    row = catalog_row(id)
    item = prompt_summary(row.fetch("id"), state)
    item[:state] = state.fetch("prompts").fetch(id)
    item[:dependency_states] = row.fetch("depends_on").to_h do |dep|
      [dep, state.fetch("prompts").fetch(dep).fetch("status")]
    end

    if json
      puts JSON.pretty_generate(item)
    else
      puts "#{item[:id]} — #{item[:title]}"
      puts "Phase: #{item[:phase]}"
      puts "Reasoning: #{item[:reasoning]}"
      puts "File: #{item[:filename]}"
      puts "Status: #{item[:state]["status"]}"
      puts "Dependencies: #{item[:depends_on].empty? ? "none" : item[:depends_on].join(", ")}"
      puts "Attempts: #{item[:state]["attempts"]}"
      puts "Started: #{item[:state]["started_at"] || "-"}"
      puts "Finished: #{item[:state]["finished_at"] || "-"}"
      puts "Block reason: #{item[:state]["block_reason"] || "-"}"
      puts "Summary: #{item[:state]["summary"] || "-"}"
      puts "Result: #{item[:state]["result_file"] || "-"}"
    end
  end

  def history(limit: nil, json: false)
    state = load_state
    events = state.fetch("history")
    events = events.last(limit) if limit
    if json
      puts JSON.pretty_generate(events)
    else
      if events.empty?
        puts "No tracker events recorded."
      else
        events.each do |event|
          detail = event["summary"] || event["reason"] || ""
          puts "#{event["at"]}  #{event["prompt_id"]}  #{event["event"]}  #{detail}"
        end
      end
    end
  end

  def start(id)
    row = catalog_row(id)
    with_locked_state do |state|
      validate_state_or_raise!(state)
      entry = state.fetch("prompts").fetch(id)
      raise TrackerError, "prompt #{id} is #{entry["status"]}, not pending" unless entry.fetch("status") == "pending"
      if state["current_prompt"]
        raise TrackerError, "prompt #{state["current_prompt"]} is already in progress"
      end

      incomplete = row.fetch("depends_on").reject do |dep|
        state.fetch("prompts").fetch(dep).fetch("status") == "completed"
      end
      unless incomplete.empty?
        statuses = incomplete.map { |dep| "#{dep}=#{state.fetch("prompts").fetch(dep).fetch("status")}" }
        raise TrackerError, "dependencies are not completed: #{statuses.join(", ")}"
      end

      now = utc_now
      entry["status"] = "in_progress"
      entry["attempts"] = entry.fetch("attempts", 0) + 1
      entry["started_at"] = now
      entry["finished_at"] = nil
      entry["blocked_at"] = nil
      entry["block_reason"] = nil
      entry["summary"] = nil
      entry["result_file"] = nil
      entry["commit"] = nil
      state["current_prompt"] = id
      event = event_hash("started", id, at: now)
      state.fetch("history") << event
      append_jsonl(event)
      append_markdown_log(now, id, "started", row.fetch("title"))
    end
    puts "STARTED #{id} — #{row.fetch("title")}"
  end

  def complete(id, options)
    row = catalog_row(id)
    summary = options.fetch(:summary, "").strip
    raise TrackerError, "--summary is required" if summary.empty?

    tests = Array(options[:tests])
    if tests.empty? && options[:legacy_tests]
      tests = [parse_legacy_test(options[:legacy_tests])]
    end
    raise TrackerError, "at least one --test or --tests entry is required" if tests.empty?

    invalid = tests.reject { |t| TEST_OUTCOMES.include?(t.fetch("outcome")) }
    raise TrackerError, "invalid test outcome" unless invalid.empty?
    failed = tests.select { |t| t.fetch("outcome") == "failed" }
    raise TrackerError, "cannot complete with failed tests: #{failed.map { |t| t["command"] }.join(", ")}" unless failed.empty?
    not_run = tests.select { |t| t.fetch("outcome") == "not_run" }
    if !not_run.empty? && !options[:allow_not_run]
      raise TrackerError, "not_run tests require --allow-not-run and an explicit risk/next step"
    end

    files = split_list(options[:files])
    migrations = split_list(options[:migrations])
    decisions = split_list(options[:decisions])
    risks = split_list(options[:risks])
    next_steps = split_list(options[:next_steps])
    risks = ["none reported"] if risks.empty?
    next_steps = ["follow the dependency graph"] if next_steps.empty?

    if !not_run.empty? && risks == ["none reported"]
      raise TrackerError, "--allow-not-run requires a non-empty --risks explanation"
    end

    with_locked_state do |state|
      validate_state_or_raise!(state)
      entry = state.fetch("prompts").fetch(id)
      unless state["current_prompt"] == id && entry.fetch("status") == "in_progress"
        raise TrackerError, "prompt #{id} is not the current in-progress prompt"
      end

      now = utc_now
      result = {
        "prompt_id" => id,
        "title" => row.fetch("title"),
        "status" => "completed",
        "started_at" => entry.fetch("started_at"),
        "finished_at" => now,
        "summary" => summary,
        "tests" => tests,
        "files_changed" => files,
        "migrations" => migrations,
        "decisions" => decisions,
        "risks" => risks,
        "next_steps" => next_steps,
        "commit" => blank_to_nil(options[:commit])
      }

      json_rel = File.join("tracking", "results", "#{id}.json")
      md_rel = File.join("tracking", "results", "#{id}.md")
      atomic_write(File.join(root, json_rel), JSON.pretty_generate(result) + "\n")
      atomic_write(File.join(root, md_rel), render_result_markdown(result))

      entry["status"] = "completed"
      entry["finished_at"] = now
      entry["blocked_at"] = nil
      entry["block_reason"] = nil
      entry["summary"] = summary
      entry["result_file"] = json_rel
      entry["commit"] = result["commit"]
      state["current_prompt"] = nil

      event = event_hash("completed", id, at: now, summary: summary, result_file: json_rel, commit: result["commit"])
      state.fetch("history") << event
      append_jsonl(event)
      append_markdown_log(now, id, "completed", summary)
    end

    puts "COMPLETED #{id} — #{row.fetch("title")}"
  end

  def block(id, reason)
    row = catalog_row(id)
    reason = reason.to_s.strip
    raise TrackerError, "--reason is required" if reason.empty?

    with_locked_state do |state|
      validate_state_or_raise!(state)
      entry = state.fetch("prompts").fetch(id)
      unless %w[pending in_progress].include?(entry.fetch("status"))
        raise TrackerError, "prompt #{id} is #{entry["status"]}; only pending/in_progress prompts can be blocked"
      end
      if state["current_prompt"] && state["current_prompt"] != id
        raise TrackerError, "prompt #{state["current_prompt"]} is in progress; block or complete it first"
      end

      now = utc_now
      entry["status"] = "blocked"
      entry["blocked_at"] = now
      entry["block_reason"] = reason
      state["current_prompt"] = nil if state["current_prompt"] == id
      event = event_hash("blocked", id, at: now, reason: reason)
      state.fetch("history") << event
      append_jsonl(event)
      append_markdown_log(now, id, "blocked", reason)
      append_blocker(now, id, reason)
    end
    puts "BLOCKED #{id} — #{row.fetch("title")}"
  end

  def unblock(id, reason)
    row = catalog_row(id)
    reason = reason.to_s.strip
    raise TrackerError, "--reason is required" if reason.empty?

    with_locked_state do |state|
      validate_state_or_raise!(state)
      entry = state.fetch("prompts").fetch(id)
      raise TrackerError, "prompt #{id} is not blocked" unless entry.fetch("status") == "blocked"

      now = utc_now
      old_reason = entry["block_reason"]
      entry["status"] = "pending"
      entry["blocked_at"] = nil
      entry["block_reason"] = nil
      event = event_hash("unblocked", id, at: now, reason: reason, previous_reason: old_reason)
      state.fetch("history") << event
      append_jsonl(event)
      append_markdown_log(now, id, "unblocked", reason)
      append_blocker_resolution(now, id, reason)
    end
    puts "UNBLOCKED #{id} — #{row.fetch("title")}"
  end

  def reset(id, reason:, cascade: false)
    catalog_row(id)
    reason = reason.to_s.strip
    raise TrackerError, "--reason is required" if reason.empty?

    with_locked_state do |state|
      validate_state_or_raise!(state)
      affected = [id]
      downstream = transitive_dependents(id)
      active_downstream = downstream.select do |dep|
        state.fetch("prompts").fetch(dep).fetch("status") != "pending"
      end
      if !active_downstream.empty? && !cascade
        raise TrackerError, "dependent prompts have state; use --cascade to reset: #{active_downstream.join(", ")}"
      end
      affected.concat(downstream) if cascade
      affected.uniq!

      current = state["current_prompt"]
      if current && !affected.include?(current)
        raise TrackerError, "prompt #{current} is in progress and is outside the reset set"
      end

      timestamp = Time.now.utc.strftime("%Y%m%dT%H%M%SZ")
      affected.each do |prompt_id|
        entry = state.fetch("prompts").fetch(prompt_id)
        next if entry.fetch("status") == "pending" &&
                entry["started_at"].nil? &&
                entry["result_file"].nil? &&
                entry["block_reason"].nil?

        archive_result(prompt_id, timestamp)
        entry["status"] = "pending"
        entry["started_at"] = nil
        entry["finished_at"] = nil
        entry["blocked_at"] = nil
        entry["block_reason"] = nil
        entry["summary"] = nil
        entry["result_file"] = nil
        entry["commit"] = nil
      end
      state["current_prompt"] = nil if current && affected.include?(current)
      now = utc_now
      event = event_hash("reset", id, at: now, reason: reason, affected: affected)
      state.fetch("history") << event
      append_jsonl(event)
      append_markdown_log(now, id, "reset", "#{reason}; affected=#{affected.join(",")}")
    end
    puts "RESET #{id}#{cascade ? " and dependents" : ""}"
  end

  private

  def load_catalog
    raise TrackerError, "missing catalog: #{@catalog_path}" unless File.file?(@catalog_path)

    rows = {}
    CSV.foreach(@catalog_path, headers: true) do |row|
      id = row["id"].to_s.strip
      raise TrackerError, "duplicate catalog ID #{id}" if rows.key?(id)
      rows[id] = {
        "id" => id,
        "phase" => row["phase"].to_s,
        "title" => row["title"].to_s,
        "filename" => row["filename"].to_s,
        "reasoning" => row["reasoning"].to_s,
        "depends_on" => row["depends_on"].to_s.split("|").reject(&:empty?)
      }
    end
    rows
  rescue CSV::MalformedCSVError => e
    raise TrackerError, "malformed catalog CSV: #{e.message}"
  end

  def validate_catalog!
    raise TrackerError, "catalog is empty" if @catalog.empty?
    errors = []
    @catalog.each do |id, row|
      errors << "invalid prompt ID #{id.inspect}" unless id.match?(/\A\d{3}\z/)
      errors << "missing title for #{id}" if row.fetch("title").strip.empty?
      errors << "invalid reasoning for #{id}" unless %w[low medium high xhigh].include?(row.fetch("reasoning"))
      filename = File.join(root, row.fetch("filename"))
      errors << "missing prompt file for #{id}: #{row.fetch("filename")}" unless File.file?(filename)
      row.fetch("depends_on").each do |dep|
        errors << "unknown dependency #{dep} for #{id}" unless @catalog.key?(dep)
        errors << "self dependency for #{id}" if dep == id
      end
    end
    cycle = dependency_cycle
    errors << "dependency cycle: #{cycle.join(" -> ")}" if cycle
    raise TrackerError, errors.join("; ") unless errors.empty?
  end

  def dependency_cycle
    visiting = {}
    visited = {}
    stack = []
    found = nil

    visit = lambda do |id|
      return if visited[id] || found
      if visiting[id]
        index = stack.index(id) || 0
        found = stack[index..] + [id]
        return
      end
      visiting[id] = true
      stack << id
      @catalog.fetch(id).fetch("depends_on").each { |dep| visit.call(dep) }
      stack.pop
      visiting.delete(id)
      visited[id] = true
    end

    @catalog.each_key { |id| visit.call(id) }
    found
  end

  def load_state
    raise TrackerError, "missing state: #{@state_path}" unless File.file?(@state_path)
    JSON.parse(File.read(@state_path))
  rescue JSON::ParserError => e
    raise TrackerError, "invalid state JSON: #{e.message}"
  end

  def validate_state(state)
    errors = []
    errors << "schema_version must be 1" unless state["schema_version"] == 1
    actual_checksum = Digest::SHA256.file(@catalog_path).hexdigest
    errors << "catalog checksum mismatch; review/migrate state intentionally" unless state["catalog_sha256"] == actual_checksum

    prompt_states = state["prompts"]
    unless prompt_states.is_a?(Hash)
      return errors << "state.prompts must be an object"
    end

    missing = @catalog.keys - prompt_states.keys
    extra = prompt_states.keys - @catalog.keys
    errors << "state missing prompts: #{missing.join(", ")}" unless missing.empty?
    errors << "state has unknown prompts: #{extra.join(", ")}" unless extra.empty?

    in_progress = []
    (@catalog.keys & prompt_states.keys).each do |id|
      entry = prompt_states.fetch(id)
      status = entry["status"]
      errors << "invalid status #{status.inspect} for #{id}" unless VALID_STATUSES.include?(status)
      in_progress << id if status == "in_progress"

      if status == "completed"
        json_path = File.join(@results_dir, "#{id}.json")
        md_path = File.join(@results_dir, "#{id}.md")
        errors << "completed #{id} missing JSON result" unless File.file?(json_path)
        errors << "completed #{id} missing Markdown result" unless File.file?(md_path)
        if File.file?(json_path)
          begin
            result = JSON.parse(File.read(json_path))
            errors << "result ID mismatch for #{id}" unless result["prompt_id"] == id
            errors << "result status mismatch for #{id}" unless result["status"] == "completed"
            errors << "state result_file mismatch for #{id}" unless entry["result_file"] == File.join("tracking", "results", "#{id}.json")
          rescue JSON::ParserError => e
            errors << "invalid result JSON for #{id}: #{e.message}"
          end
        end
      end

      if %w[in_progress completed].include?(status)
        @catalog.fetch(id).fetch("depends_on").each do |dep|
          dep_status = prompt_states.dig(dep, "status")
          errors << "#{id} is #{status} while dependency #{dep} is #{dep_status}" unless dep_status == "completed"
        end
      end
    end

    errors << "more than one prompt is in progress: #{in_progress.join(", ")}" if in_progress.length > 1
    current = state["current_prompt"]
    if current
      errors << "current_prompt #{current} is not in catalog" unless @catalog.key?(current)
      errors << "current_prompt #{current} is not in_progress" unless prompt_states.dig(current, "status") == "in_progress"
      errors << "current_prompt does not match in_progress prompt" unless in_progress == [current]
    elsif !in_progress.empty?
      errors << "in_progress prompt exists but current_prompt is null"
    end

    errors
  end

  def validate_state_or_raise!(state)
    errors = validate_state(state)
    raise TrackerError, errors.join("; ") unless errors.empty?
  end

  def with_locked_state
    FileUtils.mkdir_p(File.dirname(@lock_path))
    File.open(@lock_path, File::RDWR | File::CREAT, 0o600) do |lock|
      lock.flock(File::LOCK_EX)
      state = load_state
      yield state
      state["updated_at"] = utc_now
      atomic_write(@state_path, JSON.pretty_generate(state) + "\n")
    ensure
      lock&.flock(File::LOCK_UN)
    end
  end

  def eligible_prompt(state)
    @catalog.values.find do |row|
      entry = state.fetch("prompts").fetch(row.fetch("id"))
      entry.fetch("status") == "pending" &&
        row.fetch("depends_on").all? { |dep| state.fetch("prompts").fetch(dep).fetch("status") == "completed" }
    end
  end

  def blocking_frontier(state)
    @catalog.values.filter_map do |row|
      id = row.fetch("id")
      entry = state.fetch("prompts").fetch(id)
      next unless entry.fetch("status") == "blocked"
      { id: id, reason: entry["block_reason"] }
    end
  end

  def prompt_summary(id, state)
    row = catalog_row(id)
    {
      id: id,
      title: row.fetch("title"),
      phase: row.fetch("phase"),
      filename: row.fetch("filename"),
      reasoning: row.fetch("reasoning"),
      depends_on: row.fetch("depends_on"),
      status: state.fetch("prompts").fetch(id).fetch("status")
    }
  end

  def catalog_row(id)
    normalized = id.to_s.strip
    row = @catalog[normalized]
    raise TrackerError, "unknown prompt ID #{normalized.inspect}" unless row
    row
  end

  def parse_legacy_test(value)
    text = value.to_s.strip
    raise TrackerError, "--tests cannot be empty" if text.empty?
    outcome =
      if text.match?(/\b(fail|failed|failure)\b/i)
        "failed"
      elsif text.match?(/\b(not[_ -]?run|not applicable|n\/a)\b/i)
        "not_run"
      else
        "passed"
      end
    { "command" => text, "outcome" => outcome, "notes" => "Recorded through legacy --tests option." }
  end

  def self.parse_test(value)
    command, outcome, notes = value.to_s.split("::", 3)
    command = command.to_s.strip
    outcome = outcome.to_s.strip
    notes = notes.to_s.strip
    raise TrackerError, "test format is command::passed|failed|not_run::notes" if command.empty? || !TEST_OUTCOMES.include?(outcome)
    { "command" => command, "outcome" => outcome, "notes" => notes }
  end

  def split_list(value)
    Array(value).flat_map { |item| item.to_s.split(",") }.map(&:strip).reject(&:empty?)
  end

  def blank_to_nil(value)
    value.to_s.strip.empty? ? nil : value.to_s.strip
  end

  def utc_now
    Time.now.utc.iso8601
  end

  def event_hash(event, id, at:, **extra)
    { "at" => at, "event" => event, "prompt_id" => id }.merge(extra.transform_keys(&:to_s))
  end

  def append_jsonl(event)
    FileUtils.mkdir_p(File.dirname(@jsonl_path))
    File.open(@jsonl_path, "a", 0o600) { |file| file.puts(JSON.generate(event)) }
  end

  def append_markdown_log(at, id, event, summary)
    FileUtils.mkdir_p(File.dirname(@markdown_log_path))
    escaped = summary.to_s.gsub("|", "\\|").gsub(/\s+/, " ").strip
    File.open(@markdown_log_path, "a") { |file| file.puts("| #{at} | #{id} | #{event} | #{escaped} |") }
  end

  def append_blocker(at, id, reason)
    escaped = reason.gsub("|", "\\|").gsub(/\s+/, " ").strip
    File.open(@blockers_path, "a") { |file| file.puts("| #{at} | #{id} | #{escaped} | — |") }
  end

  def append_blocker_resolution(at, id, reason)
    escaped = reason.gsub("|", "\\|").gsub(/\s+/, " ").strip
    File.open(@blockers_path, "a") { |file| file.puts("| #{at} | #{id} | Resolution: #{escaped} | resolved |") }
  end

  def atomic_write(path, content)
    FileUtils.mkdir_p(File.dirname(path))
    temp = "#{path}.tmp.#{$$}.#{rand(1_000_000)}"
    File.open(temp, "w", 0o600) do |file|
      file.write(content)
      file.flush
      file.fsync
    end
    File.rename(temp, path)
  ensure
    FileUtils.rm_f(temp) if defined?(temp) && temp
  end

  def render_result_markdown(result)
    test_rows = result.fetch("tests").map do |test|
      command = test.fetch("command").gsub("|", "\\|").gsub("\n", " ")
      notes = test.fetch("notes", "").gsub("|", "\\|").gsub("\n", " ")
      "| `#{command}` | #{test.fetch("outcome")} | #{notes} |"
    end.join("\n")

    section = lambda do |items|
      items.empty? ? "- None" : items.map { |item| "- #{item}" }.join("\n")
    end

    <<~MARKDOWN
      # Prompt #{result.fetch("prompt_id")} Result — #{result.fetch("title")}

      - Status: completed
      - Started: #{result.fetch("started_at")}
      - Finished: #{result.fetch("finished_at")}
      - Commit: #{result["commit"] || "none recorded"}

      ## Summary

      #{result.fetch("summary")}

      ## Tests

      | Command | Outcome | Notes |
      |---|---|---|
      #{test_rows}

      ## Files changed

      #{section.call(result.fetch("files_changed"))}

      ## Migrations

      #{section.call(result.fetch("migrations"))}

      ## Decisions

      #{section.call(result.fetch("decisions"))}

      ## Remaining risks

      #{section.call(result.fetch("risks"))}

      ## Next steps

      #{section.call(result.fetch("next_steps"))}
    MARKDOWN
  end

  def transitive_dependents(id)
    result = []
    queue = [id]
    until queue.empty?
      current = queue.shift
      direct = @catalog.values.select { |row| row.fetch("depends_on").include?(current) }.map { |row| row.fetch("id") }
      direct.each do |dep|
        next if result.include?(dep)
        result << dep
        queue << dep
      end
    end
    result
  end

  def archive_result(id, timestamp)
    FileUtils.mkdir_p(@archive_dir)
    %w[json md].each do |ext|
      source = File.join(@results_dir, "#{id}.#{ext}")
      next unless File.file?(source)
      destination = File.join(@archive_dir, "#{id}.#{timestamp}.#{ext}")
      FileUtils.mv(source, destination)
    end
  end
end

def usage
  <<~TEXT
    Usage:
      prompt_tracker.rb validate
      prompt_tracker.rb status [--json]
      prompt_tracker.rb next [--json]
      prompt_tracker.rb show ID [--json]
      prompt_tracker.rb history [--limit N] [--json]
      prompt_tracker.rb start ID
      prompt_tracker.rb complete ID --summary TEXT --test "command::passed::notes" [options]
      prompt_tracker.rb block ID --reason TEXT
      prompt_tracker.rb unblock ID --reason TEXT
      prompt_tracker.rb reset ID --reason TEXT [--cascade]
  TEXT
end

root = ENV.fetch("SEARCHOPS_TRACKER_ROOT", File.expand_path("../..", __dir__))
command = ARGV.shift

begin
  raise TrackerError, usage unless command
  tracker = PromptTracker.new(root)

  case command
  when "validate"
    raise TrackerError, "validate takes no arguments" unless ARGV.empty?
    tracker.validate!
  when "status"
    options = { json: false }
    OptionParser.new { |o| o.on("--json") { options[:json] = true } }.parse!(ARGV)
    raise TrackerError, "unexpected arguments: #{ARGV.join(" ")}" unless ARGV.empty?
    tracker.status(**options)
  when "next"
    options = { json: false }
    OptionParser.new { |o| o.on("--json") { options[:json] = true } }.parse!(ARGV)
    raise TrackerError, "unexpected arguments: #{ARGV.join(" ")}" unless ARGV.empty?
    tracker.next_prompt(**options)
  when "show"
    id = ARGV.shift
    raise TrackerError, "show requires an ID" unless id
    options = { json: false }
    OptionParser.new { |o| o.on("--json") { options[:json] = true } }.parse!(ARGV)
    raise TrackerError, "unexpected arguments: #{ARGV.join(" ")}" unless ARGV.empty?
    tracker.show(id, **options)
  when "history"
    options = { json: false, limit: nil }
    OptionParser.new do |o|
      o.on("--json") { options[:json] = true }
      o.on("--limit N", Integer) { |v| options[:limit] = v }
    end.parse!(ARGV)
    raise TrackerError, "unexpected arguments: #{ARGV.join(" ")}" unless ARGV.empty?
    tracker.history(**options)
  when "start"
    id = ARGV.shift
    raise TrackerError, "start requires an ID" unless id
    raise TrackerError, "unexpected arguments: #{ARGV.join(" ")}" unless ARGV.empty?
    tracker.start(id)
  when "complete"
    id = ARGV.shift
    raise TrackerError, "complete requires an ID" unless id
    options = { tests: [], allow_not_run: false }
    OptionParser.new do |o|
      o.on("--summary TEXT") { |v| options[:summary] = v }
      o.on("--test SPEC") { |v| options[:tests] << PromptTracker.parse_test(v) }
      o.on("--tests TEXT") { |v| options[:legacy_tests] = v }
      o.on("--allow-not-run") { options[:allow_not_run] = true }
      o.on("--files LIST") { |v| options[:files] = v }
      o.on("--migrations LIST") { |v| options[:migrations] = v }
      o.on("--decisions LIST") { |v| options[:decisions] = v }
      o.on("--risks LIST") { |v| options[:risks] = v }
      o.on("--next-steps LIST") { |v| options[:next_steps] = v }
      o.on("--commit SHA") { |v| options[:commit] = v }
    end.parse!(ARGV)
    raise TrackerError, "unexpected arguments: #{ARGV.join(" ")}" unless ARGV.empty?
    tracker.complete(id, options)
  when "block"
    id = ARGV.shift
    raise TrackerError, "block requires an ID" unless id
    options = {}
    OptionParser.new { |o| o.on("--reason TEXT") { |v| options[:reason] = v } }.parse!(ARGV)
    raise TrackerError, "unexpected arguments: #{ARGV.join(" ")}" unless ARGV.empty?
    tracker.block(id, options[:reason])
  when "unblock"
    id = ARGV.shift
    raise TrackerError, "unblock requires an ID" unless id
    options = {}
    OptionParser.new { |o| o.on("--reason TEXT") { |v| options[:reason] = v } }.parse!(ARGV)
    raise TrackerError, "unexpected arguments: #{ARGV.join(" ")}" unless ARGV.empty?
    tracker.unblock(id, options[:reason])
  when "reset"
    id = ARGV.shift
    raise TrackerError, "reset requires an ID" unless id
    options = { cascade: false }
    OptionParser.new do |o|
      o.on("--reason TEXT") { |v| options[:reason] = v }
      o.on("--cascade") { options[:cascade] = true }
    end.parse!(ARGV)
    raise TrackerError, "unexpected arguments: #{ARGV.join(" ")}" unless ARGV.empty?
    tracker.reset(id, reason: options[:reason], cascade: options[:cascade])
  else
    raise TrackerError, "unknown command #{command.inspect}\n#{usage}"
  end
rescue TrackerError, OptionParser::ParseError => e
  warn "ERROR: #{e.message}"
  exit 1
end
