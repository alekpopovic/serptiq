#!/usr/bin/env ruby
# frozen_string_literal: true

require "csv"
require "date"
require "json"
require "open3"
require "pathname"
require "yaml"

ROOT = Pathname.new(ENV.fetch("SEARCHOPS_TRACKER_ROOT", File.expand_path("../..", __dir__))).expand_path

class ValidationFailure < StandardError; end

def fail_if(condition, message)
  raise ValidationFailure, message if condition
end

def load_yaml(path)
  YAML.safe_load(
    path.read.force_encoding(Encoding::UTF_8),
    permitted_classes: [ Date ],
    permitted_symbols: [],
    aliases: false
  )
rescue Psych::Exception => e
  raise ValidationFailure, "invalid YAML #{path.relative_path_from(ROOT)}: #{e.message}"
end

def extract_frontmatter(path)
  text = path.read.force_encoding(Encoding::UTF_8)
  match = text.match(/\A---\s*\n(.*?)\n---\s*\n/m)
  raise ValidationFailure, "missing frontmatter: #{path.relative_path_from(ROOT)}" unless match
  YAML.safe_load(match[1], permitted_classes: [], permitted_symbols: [], aliases: false)
rescue Psych::Exception => e
  raise ValidationFailure, "invalid frontmatter #{path.relative_path_from(ROOT)}: #{e.message}"
end

begin
  catalog_path = ROOT.join("tracking", "prompt_catalog.csv")
  fail_if(!catalog_path.file?, "missing prompt catalog")
  rows = CSV.read(catalog_path, headers: true).map(&:to_h)
  fail_if(rows.length != 120, "expected 120 catalog rows, got #{rows.length}")

  expected_ids = (0...120).map { |i| format("%03d", i) }
  ids = rows.map { |row| row.fetch("id") }
  fail_if(ids != expected_ids, "prompt IDs are not exactly 000..119 in order")
  fail_if(ids.uniq.length != ids.length, "duplicate prompt IDs")

  rows.each do |row|
    id = row.fetch("id")
    prompt_path = ROOT.join(row.fetch("filename"))
    fail_if(!prompt_path.file?, "missing prompt file for #{id}: #{row.fetch("filename")}")
    meta = extract_frontmatter(prompt_path)
    fail_if(meta["id"].to_s != id, "frontmatter ID mismatch for #{id}")
    fail_if(meta["title"].to_s != row.fetch("title"), "frontmatter title mismatch for #{id}")
    fail_if(meta["phase"].to_s != row.fetch("phase"), "frontmatter phase mismatch for #{id}")
    fail_if(meta["recommended_reasoning"].to_s != row.fetch("reasoning"), "frontmatter reasoning mismatch for #{id}")
    deps = row.fetch("depends_on").to_s.split("|").reject(&:empty?)
    fail_if(Array(meta["depends_on"]).map(&:to_s) != deps, "frontmatter dependencies mismatch for #{id}")
    fail_if(!%w[low medium high xhigh].include?(row.fetch("reasoning")), "invalid reasoning for #{id}")
    deps.each do |dep|
      fail_if(!ids.include?(dep), "unknown dependency #{dep} for #{id}")
      fail_if(dep == id, "self dependency for #{id}")
    end
  end

  prompt_files = ROOT.join("prompts").glob("[0-9][0-9][0-9]_*.md")
  fail_if(prompt_files.length != 120, "expected 120 numbered prompt files, got #{prompt_files.length}")

  permissions = load_yaml(ROOT.join("config_blueprints", "permissions.yml"))
  permission_rows = permissions.fetch("permissions")
  permission_keys = permission_rows.map { |row| row.fetch("key") }
  fail_if(permission_rows.length != 57, "expected 57 permissions, got #{permission_rows.length}")
  fail_if(permission_keys.uniq.length != permission_keys.length, "duplicate permission key")
  permission_rows.each do |permission|
    key = permission.fetch("key")
    fail_if(permission.fetch("category").to_s.strip.empty?, "permission #{key} lacks category")
    fail_if(permission.fetch("description").to_s.strip.empty?, "permission #{key} lacks description")
    fail_if(!%w[organization project].include?(permission.fetch("scope")), "permission #{key} has invalid scope")
    fail_if(!%w[low medium high critical].include?(permission.fetch("risk")), "permission #{key} has invalid risk")
  end
  roles = permissions.fetch("system_roles")
  fail_if(roles.length != 8, "expected 8 system roles, got #{roles.length}")
  role_keys = roles.map { |row| row.fetch("key") }
  fail_if(role_keys.uniq.length != role_keys.length, "duplicate system role key")
  roles.each do |role|
    grants = role.fetch("permissions")
    fail_if(grants.uniq.length != grants.length, "role #{role.fetch("key")} has duplicate permissions")
    scopes = role.fetch("assignable_scopes")
    fail_if(scopes.empty? || scopes.uniq.length != scopes.length || (scopes - %w[organization project]).any?,
      "role #{role.fetch("key")} has invalid assignable scopes")
    unknown = grants - permission_keys
    fail_if(!unknown.empty?, "role #{role.fetch("key")} has unknown permissions: #{unknown.join(", ")}")
  end
  owner = roles.find { |role| role.fetch("key") == "owner" }
  fail_if(owner.nil? || owner.fetch("permissions").sort != permission_keys.sort,
    "owner role must include every permission")

  plans = load_yaml(ROOT.join("config_blueprints", "plans.yml"))
  plan_rows = plans.fetch("plans")
  fail_if(plan_rows.length != 5, "expected 5 plans, got #{plan_rows.length}")
  plan_keys = plan_rows.map { |row| row.fetch("key") }
  fail_if(plan_keys.uniq.length != plan_keys.length, "duplicate plan key")
  entitlement_key_sets = plan_rows.map { |row| row.fetch("entitlements").keys.sort }
  fail_if(entitlement_key_sets.first.length != 47, "expected 47 entitlement keys, got #{entitlement_key_sets.first.length}")
  entitlement_key_sets.each_with_index do |set, index|
    fail_if(set != entitlement_key_sets.first, "plan #{plan_rows[index].fetch("key")} has a different entitlement key set")
  end

  rules = load_yaml(ROOT.join("config_blueprints", "seo_rules.yml"))
  rule_rows = rules.fetch("rules")
  fail_if(rule_rows.length != 96, "expected 96 rules, got #{rule_rows.length}")
  rule_keys = rule_rows.map { |row| row.fetch("key") }
  fail_if(rule_keys.uniq.length != rule_keys.length, "duplicate SEO rule key")

  ROOT.join("schemas").glob("*.json").each do |path|
    JSON.parse(path.read.force_encoding(Encoding::UTF_8))
  rescue JSON::ParserError => e
    raise ValidationFailure, "invalid JSON #{path.relative_path_from(ROOT)}: #{e.message}"
  end
  schema_count = ROOT.join("schemas").glob("*.json").length
  fail_if(schema_count != 4, "expected 4 JSON schemas, got #{schema_count}")

  markdown_paths = ROOT.glob("**/*.md")
  markdown_paths.each do |path|
    path.read.force_encoding(Encoding::UTF_8).scan(/\]\((?!https?:|mailto:|#)([^)]+)\)/).flatten.each do |raw_target|
      target = raw_target.split("#", 2).first
      next if target.nil? || target.empty?
      candidate = path.dirname.join(target).cleanpath
      fail_if(!candidate.exist?, "broken relative link in #{path.relative_path_from(ROOT)}: #{raw_target}")
    end
  end

  allowed_empty = [ ROOT.join("tracking", "execution_log.jsonl").to_s ]
  ROOT.glob("**/*").select(&:file?).each do |path|
    next if allowed_empty.include?(path.to_s)
    fail_if(path.size.zero?, "unexpected empty file: #{path.relative_path_from(ROOT)}")
  end

  tracker = ROOT.join("tracking", "scripts", "prompt_tracker.rb")
  stdout, stderr, status = Open3.capture3(
    { "SEARCHOPS_TRACKER_ROOT" => ROOT.to_s, "LANG" => "C.UTF-8", "LC_ALL" => "C.UTF-8" },
    RbConfig.ruby,
    tracker.to_s,
    "validate"
  )
  fail_if(!status.success?, "tracker validation failed: #{stdout}#{stderr}")

  puts "BLUEPRINT VALID"
  puts "  prompts: 120"
  puts "  permissions: 57"
  puts "  roles: 8"
  puts "  plans: 5"
  puts "  entitlements per plan: 47"
  puts "  SEO rules: 96"
  puts "  ADRs: #{ROOT.join("docs", "adr").glob("[0-9][0-9][0-9][0-9]_*.md").length}"
  puts "  JSON schemas: #{schema_count}"
rescue KeyError => e
  warn "ERROR: missing required key: #{e.message}"
  exit 1
rescue ValidationFailure => e
  warn "ERROR: #{e.message}"
  exit 1
end
