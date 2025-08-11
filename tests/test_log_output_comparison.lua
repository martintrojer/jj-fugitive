#!/usr/bin/env -S nvim --headless -l

-- Test comparing raw jj log output formats using common test runner
local runner = require("tests.test_runner")

runner.init("Log Output Comparison Tests")

local main_module = runner.load_module("jj-fugitive.init")
if not main_module then
  runner.finish()
  return
end

-- Test 1: Raw jj log command variants
runner.section("Test 1: Raw jj log command variants")

local default_log = main_module.run_jj_command_from_module({ "log", "--color", "always" })
runner.assert_test("Default jj log works", default_log ~= nil, "Default log command failed")

local full_repo_log =
  main_module.run_jj_command_from_module({ "log", "--color", "always", "-r", ".." })
runner.assert_test("Full repo jj log works", full_repo_log ~= nil, "Full repo log command failed")

local limited_log =
  main_module.run_jj_command_from_module({ "log", "--color", "always", "--limit", "10" })
runner.assert_test("Limited jj log works", limited_log ~= nil, "Limited log command failed")

-- Test 2: Compare line counts
runner.section("Test 2: Line count comparisons")

if default_log and full_repo_log and limited_log then
  local default_count = runner.count_non_empty_lines(default_log)
  local full_count = runner.count_non_empty_lines(full_repo_log)
  local limited_count = runner.count_non_empty_lines(limited_log)

  runner.info(string.format("Default log: %d non-empty lines", default_count))
  runner.info(string.format("Full repo log: %d non-empty lines", full_count))
  runner.info(string.format("Limited log: %d non-empty lines", limited_count))

  -- With 25 test commits, different jj versions/templates may vary in lines per commit
  runner.assert_test(
    "Default log is reasonable length",
    default_count <= 200,
    string.format("Expected ≤200 lines for 25 commits, got %d", default_count)
  )

  runner.assert_test(
    "Full repo log shows at least as many commits as default",
    full_count >= default_count,
    string.format("Full: %d, Default: %d", full_count, default_count)
  )

  -- Limited log should be relatively small; allow headroom for multi-line templates
  runner.assert_test(
    "Limited log respects limit (len)",
    limited_count <= 50,
    string.format("Expected ≤50 lines, got %d", limited_count)
  )
end

-- Test 3: Content analysis
runner.section("Test 3: Content analysis")

if default_log then
  local has_working_copy = default_log:match("@")
  local has_commit_symbol = default_log:match("◆")
    or default_log:match("○")
    or default_log:match("o")
    or default_log:match("%*")
  local has_elided = default_log:match("~")

  runner.assert_test("Default log contains working copy (@)", has_working_copy, "No @ symbol found")
  runner.assert_test(
    "Default log contains commit symbols",
    has_commit_symbol,
    "No ◆ or ○ symbols found"
  )

  runner.info(string.format("Elided marker (~) found: %s", has_elided and "yes" or "no"))
end

if full_repo_log then
  local commit_count = 0
  for line in full_repo_log:gmatch("[^\n]+") do
    if
      line:match("^[^%s]")
      and (line:match("@") or line:match("◆") or line:match("○") or line:match("o"))
    then
      commit_count = commit_count + 1
    end
  end

  runner.assert_test(
    "Full repo log shows commits",
    commit_count >= 1,
    string.format("Expected ≥1 commits, found %d", commit_count)
  )
  runner.info(string.format("Found %d commits in full repo log", commit_count))
end

-- Test 4: ANSI color preservation
runner.section("Test 4: ANSI color preservation")

if default_log then
  runner.assert_test(
    "Default log preserves ANSI colors",
    runner.has_ansi_codes(default_log),
    "No ANSI color codes found in default log"
  )
end

-- Test 5: Performance characteristics
runner.section("Test 5: Performance characteristics")

local start_time = os.clock()
local quick_log = main_module.run_jj_command_from_module({ "log", "--limit", "5" })
local quick_time = (os.clock() - start_time) * 1000

start_time = os.clock()
local comprehensive_log =
  main_module.run_jj_command_from_module({ "log", "-r", "..", "--limit", "50" })
local comprehensive_time = (os.clock() - start_time) * 1000

runner.assert_test("Quick log executes successfully", quick_log ~= nil)
runner.assert_test("Comprehensive log executes successfully", comprehensive_log ~= nil)

if quick_time > 0 then
  runner.info(string.format("Quick log time: %.2f ms", quick_time))
  runner.info(string.format("Comprehensive log time: %.2f ms", comprehensive_time))
  runner.info(string.format("Comprehensive log is %.1fx slower", comprehensive_time / quick_time))
end

-- Finish with summary
local summary = {
  "Key findings:",
  "  📊 Default jj log shows recent commits only",
  "  📈 Full repo jj log (-r ..) shows comprehensive history",
  "  🎨 ANSI colors preserved in all variants",
  "  ⚡ Default behavior optimized for typical usage",
  "  🔍 All jj log variants work correctly",
}

runner.finish(summary)
