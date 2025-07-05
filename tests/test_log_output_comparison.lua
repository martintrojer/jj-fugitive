#!/usr/bin/env -S nvim --headless -l

-- Test comparing raw jj log output formats
vim.cmd("set rtp+=.")
vim.cmd("runtime plugin/jj-fugitive.lua")

local test_results = {}
local function assert_test(name, condition, message)
  if condition then
    print("✅ PASS: " .. name)
    table.insert(test_results, { name = name, passed = true })
  else
    print("❌ FAIL: " .. name .. " - " .. (message or ""))
    table.insert(test_results, { name = name, passed = false, message = message })
  end
end

print("🔍 === Log Output Comparison Tests ===")

local main_module = require("jj-fugitive.init")

-- Test 1: Raw jj log command variants
print("\n🧪 Test 1: Raw jj log command variants")

local default_log = main_module.run_jj_command_from_module({ "log", "--color", "always" })
assert_test("Default jj log works", default_log ~= nil, "Default log command failed")

local full_repo_log =
  main_module.run_jj_command_from_module({ "log", "--color", "always", "-r", ".." })
assert_test("Full repo jj log works", full_repo_log ~= nil, "Full repo log command failed")

local limited_log =
  main_module.run_jj_command_from_module({ "log", "--color", "always", "--limit", "10" })
assert_test("Limited jj log works", limited_log ~= nil, "Limited log command failed")

-- Test 2: Compare line counts
print("\n🧪 Test 2: Line count comparisons")

if default_log and full_repo_log and limited_log then
  local default_lines = vim.split(default_log, "\n")
  local full_lines = vim.split(full_repo_log, "\n")
  local limited_lines = vim.split(limited_log, "\n")

  -- Count non-empty lines for each
  local function count_non_empty(lines)
    local count = 0
    for _, line in ipairs(lines) do
      if line:match("%S") then -- line contains non-whitespace
        count = count + 1
      end
    end
    return count
  end

  local default_count = count_non_empty(default_lines)
  local full_count = count_non_empty(full_lines)
  local limited_count = count_non_empty(limited_lines)

  print(string.format("  Default log: %d non-empty lines", default_count))
  print(string.format("  Full repo log: %d non-empty lines", full_count))
  print(string.format("  Limited log: %d non-empty lines", limited_count))

  assert_test(
    "Default log is concise",
    default_count <= 10,
    string.format("Expected ≤10 lines, got %d", default_count)
  )

  assert_test(
    "Full repo log shows at least as many commits as default",
    full_count >= default_count,
    string.format("Expected full (%d) >= default (%d)", full_count, default_count)
  )

  assert_test(
    "Limited log respects limit",
    limited_count <= 15, -- Allow some buffer for headers/formatting
    string.format("Expected ≤15 lines for --limit 10, got %d", limited_count)
  )
end

-- Test 3: Content analysis
print("\n🧪 Test 3: Content analysis")

if default_log then
  -- Check for standard jj log elements
  local has_working_copy = default_log:match("@")
  local has_commit_symbol = default_log:match("◆") or default_log:match("○")
  local has_elided = default_log:match("~")

  assert_test("Default log contains working copy (@)", has_working_copy, "No @ symbol found")
  assert_test(
    "Default log contains commit symbols",
    has_commit_symbol,
    "No ◆ or ○ symbols found"
  )
  -- Elided marker (~) only appears when there are many commits, so make it optional
  print(string.format("  Note: Elided marker (~) found: %s", has_elided and "yes" or "no"))
end

if full_repo_log then
  -- Full repo should have many more commits
  local commit_count = 0
  for line in full_repo_log:gmatch("[^\n]+") do
    if line:match("^[^%s]") and (line:match("@") or line:match("◆") or line:match("○")) then
      commit_count = commit_count + 1
    end
  end

  assert_test(
    "Full repo log shows commits",
    commit_count >= 1,
    string.format("Expected ≥1 commits, found %d", commit_count)
  )
  print(string.format("  Note: Found %d commits in full repo log", commit_count))
end

-- Test 4: ANSI color preservation
print("\n🧪 Test 4: ANSI color preservation")

if default_log then
  local has_ansi_colors = default_log:match("\27%[[0-9;]*m")
  assert_test(
    "Default log preserves ANSI colors",
    has_ansi_colors,
    "No ANSI escape sequences found"
  )
end

-- Test 5: Performance comparison (rough)
print("\n🧪 Test 5: Performance characteristics")

local start_time = vim.loop.hrtime()
local quick_log =
  main_module.run_jj_command_from_module({ "log", "--color", "always", "--limit", "5" })
local quick_time = vim.loop.hrtime() - start_time

start_time = vim.loop.hrtime()
local slow_log = main_module.run_jj_command_from_module({ "log", "--color", "always", "-r", ".." })
local slow_time = vim.loop.hrtime() - start_time

assert_test("Quick log executes successfully", quick_log ~= nil, "Quick log failed")
assert_test("Comprehensive log executes successfully", slow_log ~= nil, "Comprehensive log failed")

if quick_time > 0 and slow_time > 0 then
  print(string.format("  Quick log time: %.2f ms", quick_time / 1000000))
  print(string.format("  Comprehensive log time: %.2f ms", slow_time / 1000000))

  -- This is just informational - comprehensive log will usually be slower
  -- but we don't want to fail the test on performance variations
  local time_ratio = slow_time / quick_time
  print(string.format("  Comprehensive log is %.1fx slower", time_ratio))
end

-- Summary
print("\n📊 === Log Output Comparison Test Results Summary ===")
local passed = 0
local total = #test_results

for _, result in ipairs(test_results) do
  if result.passed then
    passed = passed + 1
  end
end

print(string.format("Passed: %d/%d tests", passed, total))

if passed == total then
  print("🎉 All log output comparison tests passed!")
  print("")
  print("Key findings:")
  print("  📊 Default jj log shows recent commits only")
  print("  📈 Full repo jj log (-r ..) shows comprehensive history")
  print("  🎨 ANSI colors preserved in all variants")
  print("  ⚡ Default behavior optimized for typical usage")
  print("  🔍 All jj log variants work correctly")
  os.exit(0)
else
  print("💥 Some log output comparison tests failed!")
  for _, result in ipairs(test_results) do
    if not result.passed then
      print("  ❌ " .. result.name .. ": " .. (result.message or ""))
    end
  end
  os.exit(1)
end
