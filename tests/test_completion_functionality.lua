#!/usr/bin/env -S nvim --headless -l

-- Test completion functionality
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

print("🚀 === jj-fugitive Completion Functionality Tests ===")

-- Test 1: Check if completion module can be loaded
local completion_module = nil
pcall(function()
  completion_module = require("jj-fugitive.completion")
end)
assert_test(
  "Completion module loading",
  completion_module ~= nil,
  "Could not require jj-fugitive.completion"
)

-- Test 2: Test basic command completion
if completion_module then
  local completions = completion_module.complete("s", "J s", 3)
  assert_test(
    "Basic command completion",
    type(completions) == "table",
    "Completion should return a table"
  )

  local has_status = vim.tbl_contains(completions, "status")
  assert_test(
    "Status command in completions",
    has_status,
    "status command should be in completions"
  )

  -- Test command filtering
  local log_completions = completion_module.complete("lo", "J lo", 4)
  local has_log = vim.tbl_contains(log_completions, "log")
  local has_status_filtered = vim.tbl_contains(log_completions, "status")
  assert_test(
    "Command filtering works",
    has_log and not has_status_filtered,
    "Should filter commands based on input"
  )
end

-- Test 3: Test flag completion for a known command
if completion_module then
  local flag_completions = completion_module.complete("--", "J status --", 10)
  assert_test("Flag completion returns results", #flag_completions > 0, "Should return some flags")

  -- Test that help flag is included
  local has_help = vim.tbl_contains(flag_completions, "--help")
  assert_test("Help flag in completions", has_help, "--help should be in flag completions")
end

-- Test 4: Test bookmark completion helper
if completion_module then
  local bookmarks = completion_module.get_bookmarks()
  assert_test("Bookmark listing", type(bookmarks) == "table", "get_bookmarks should return a table")
end

-- Test 5: Test changed files helper
if completion_module then
  local files = completion_module.get_changed_files()
  assert_test(
    "Changed files listing",
    type(files) == "table",
    "get_changed_files should return a table"
  )
end

-- Test 6: Test cache clearing
if completion_module then
  local success = pcall(function()
    completion_module.clear_cache()
  end)
  assert_test("Cache clearing", success, "clear_cache should not error")
end

-- Test 7: Test main plugin completion integration
local main_module = nil
pcall(function()
  main_module = require("jj-fugitive")
end)

if main_module then
  local main_completions = main_module.complete("st", "J st", 4)
  assert_test(
    "Main plugin completion integration",
    type(main_completions) == "table",
    "Main plugin should provide completions"
  )

  local has_status_main = vim.tbl_contains(main_completions, "status")
  assert_test(
    "Main plugin has status completion",
    has_status_main,
    "Main plugin should complete status"
  )
end

-- Summary
print("\n📊 === Test Results Summary ===")
local passed = 0
local total = #test_results

for _, result in ipairs(test_results) do
  if result.passed then
    passed = passed + 1
  end
end

print(string.format("Passed: %d/%d tests", passed, total))

if passed == total then
  print("🎉 All tests passed!")
  os.exit(0)
else
  print("💥 Some tests failed!")
  for _, result in ipairs(test_results) do
    if not result.passed then
      print("  ❌ " .. result.name .. ": " .. (result.message or ""))
    end
  end
  os.exit(1)
end
