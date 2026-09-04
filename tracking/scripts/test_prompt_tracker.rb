#!/usr/bin/env ruby
# frozen_string_literal: true

require "csv"
require "digest"
require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "rbconfig"
require "tmpdir"
require "time"

class PromptTrackerCliTest < Minitest::Test
  SOURCE_SCRIPT = File.expand_path("prompt_tracker.rb", __dir__)

  def setup
    @tmp = Dir.mktmpdir("searchops-tracker-test")
    @root = File.join(@tmp, "repo")
    FileUtils.mkdir_p(File.join(@root, "tracking", "scripts"))
    FileUtils.mkdir_p(File.join(@root, "tracking", "results", "archive"))
    FileUtils.mkdir_p(File.join(@root, "prompts"))
    @script = File.join(@root, "tracking", "scripts", "prompt_tracker.rb")
    FileUtils.cp(SOURCE_SCRIPT, @script)
    FileUtils.chmod(0o755, @script)

    rows = [
      ["000", "test", "First", "prompts/000_first.md", "medium", ""],
      ["001", "test", "Second", "prompts/001_second.md", "high", "000"],
      ["002", "test", "Third", "prompts/002_third.md", "xhigh", "001"]
    ]
    catalog = File.join(@root, "tracking", "prompt_catalog.csv")
    CSV.open(catalog, "w") do |csv|
      csv << %w[id phase title filename reasoning depends_on]
      rows.each { |row| csv << row }
    end
    rows.each { |row| File.write(File.join(@root, row[3]), "# #{row[0]}\n") }

    timestamp = Time.now.utc.iso8601
    state = {
      "schema_version" => 1,
      "project" => "Tracker Test",
      "catalog_sha256" => Digest::SHA256.file(catalog).hexdigest,
      "created_at" => timestamp,
      "updated_at" => timestamp,
      "current_prompt" => nil,
      "prompts" => rows.to_h do |row|
        [
          row[0],
          {
            "status" => "pending",
            "attempts" => 0,
            "started_at" => nil,
            "finished_at" => nil,
            "blocked_at" => nil,
            "block_reason" => nil,
            "summary" => nil,
            "result_file" => nil,
            "commit" => nil
          }
        ]
      end,
      "history" => []
    }
    File.write(File.join(@root, "tracking", "state.json"), JSON.pretty_generate(state) + "\n")
    File.write(File.join(@root, "tracking", "execution_log.jsonl"), "")
    File.write(
      File.join(@root, "tracking", "EXECUTION_LOG.md"),
      "# Log\n\n| Timestamp | Prompt | Event | Summary |\n|---|---:|---|---|\n"
    )
    File.write(
      File.join(@root, "tracking", "BLOCKERS.md"),
      "# Blockers\n\n| Timestamp | Prompt | Blocker | Resolution |\n|---|---:|---|---|\n"
    )
  end

  def teardown
    FileUtils.remove_entry(@tmp) if @tmp && File.exist?(@tmp)
  end

  def run_cli(*args)
    stdout, stderr, status = Open3.capture3(
      {
        "SEARCHOPS_TRACKER_ROOT" => @root,
        "LANG" => "C.UTF-8",
        "LC_ALL" => "C.UTF-8"
      },
      RbConfig.ruby,
      @script,
      *args
    )
    [stdout.force_encoding(Encoding::UTF_8), stderr.force_encoding(Encoding::UTF_8), status]
  end

  def assert_success(result)
    stdout, stderr, status = result
    assert status.success?, "expected success\nstdout=#{stdout}\nstderr=#{stderr}"
    stdout
  end

  def assert_failure(result)
    stdout, stderr, status = result
    refute status.success?, "expected failure\nstdout=#{stdout}\nstderr=#{stderr}"
    stderr
  end

  def state
    JSON.parse(File.read(File.join(@root, "tracking", "state.json")))
  end

  def complete(id)
    assert_success(
      run_cli(
        "complete", id,
        "--summary", "Completed #{id}",
        "--test", "ruby -v::passed::ok",
        "--files", "example.rb",
        "--risks", "none",
        "--next-steps", "continue"
      )
    )
  end

  def test_validate_status_and_next_are_read_only
    before = File.read(File.join(@root, "tracking", "state.json"))
    assert_match(/VALID: 3 prompts/, assert_success(run_cli("validate")))
    assert_match(/0\/3 completed/, assert_success(run_cli("status")))
    assert_match(/000 — First/, assert_success(run_cli("next")))
    after = File.read(File.join(@root, "tracking", "state.json"))
    assert_equal before, after
  end

  def test_start_and_complete_create_consistent_results
    assert_match(/STARTED 000/, assert_success(run_cli("start", "000")))
    assert_equal "000", state["current_prompt"]
    assert_equal "in_progress", state.dig("prompts", "000", "status")

    complete("000")

    current = state
    assert_nil current["current_prompt"]
    assert_equal "completed", current.dig("prompts", "000", "status")
    json_path = File.join(@root, "tracking", "results", "000.json")
    md_path = File.join(@root, "tracking", "results", "000.md")
    assert File.file?(json_path)
    assert File.file?(md_path)
    result = JSON.parse(File.read(json_path))
    assert_equal "000", result["prompt_id"]
    assert_equal "passed", result.dig("tests", 0, "outcome")
    assert_match(/001 — Second/, assert_success(run_cli("next")))
    assert_success(run_cli("validate"))
  end

  def test_dependencies_and_single_current_are_enforced
    assert_match(/dependencies are not completed/, assert_failure(run_cli("start", "001")))
    assert_success(run_cli("start", "000"))
    assert_match(/already in progress/, assert_failure(run_cli("start", "001")))
    assert_match(/not the current/, assert_failure(
      run_cli(
        "complete", "001",
        "--summary", "wrong",
        "--test", "ruby -v::passed::ok"
      )
    ))
  end

  def test_failed_and_unacknowledged_not_run_tests_prevent_completion
    assert_success(run_cli("start", "000"))
    assert_match(/cannot complete with failed tests/, assert_failure(
      run_cli(
        "complete", "000",
        "--summary", "bad",
        "--test", "ruby -v::failed::failure"
      )
    ))
    assert_equal "in_progress", state.dig("prompts", "000", "status")

    assert_match(/require --allow-not-run/, assert_failure(
      run_cli(
        "complete", "000",
        "--summary", "not tested",
        "--test", "browser suite::not_run::browser missing"
      )
    ))
    assert_equal "in_progress", state.dig("prompts", "000", "status")
  end

  def test_block_and_unblock_preserve_history
    assert_success(run_cli("start", "000"))
    assert_success(run_cli("block", "000", "--reason", "PostgreSQL unavailable"))
    assert_equal "blocked", state.dig("prompts", "000", "status")
    assert_nil state["current_prompt"]

    assert_success(run_cli("unblock", "000", "--reason", "PostgreSQL restored"))
    assert_equal "pending", state.dig("prompts", "000", "status")
    events = state["history"].map { |event| event["event"] }
    assert_equal %w[started blocked unblocked], events
    blockers = File.read(File.join(@root, "tracking", "BLOCKERS.md"))
    assert_includes blockers, "PostgreSQL unavailable"
    assert_includes blockers, "PostgreSQL restored"
  end

  def test_file_lock_allows_only_one_concurrent_start
    results = 2.times.map do
      Thread.new { run_cli("start", "000") }
    end.map(&:value)
    successes = results.count { |result| result[2].success? }
    failures = results.count { |result| !result[2].success? }
    assert_equal 1, successes
    assert_equal 1, failures
    assert_equal "in_progress", state.dig("prompts", "000", "status")
  end

  def test_reset_requires_cascade_and_archives_results
    assert_success(run_cli("start", "000"))
    complete("000")
    assert_success(run_cli("start", "001"))
    complete("001")

    assert_match(/use --cascade/, assert_failure(
      run_cli("reset", "000", "--reason", "implementation reverted")
    ))

    assert_success(
      run_cli("reset", "000", "--reason", "implementation reverted", "--cascade")
    )
    current = state
    assert_equal "pending", current.dig("prompts", "000", "status")
    assert_equal "pending", current.dig("prompts", "001", "status")
    assert_equal "pending", current.dig("prompts", "002", "status")
    archived = Dir.glob(File.join(@root, "tracking", "results", "archive", "000.*"))
    assert_equal 2, archived.length
    assert_success(run_cli("validate"))
  end

  def test_catalog_checksum_change_is_detected
    catalog_path = File.join(@root, "tracking", "prompt_catalog.csv")
    content = File.read(catalog_path).sub(",First,", ",First changed,")
    File.write(catalog_path, content)
    assert_match(/catalog checksum mismatch/, assert_failure(run_cli("validate")))
  end
end
