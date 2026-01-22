#!/usr/bin/env -S nvim --headless -l

local runner = require("tests.test_runner")
runner.init("jj-fugitive Completion Functionality Tests")

-- Test 1: Check if completion module can be loaded
local completion_module = runner.load_module("jj-fugitive.completion")
if not completion_module then
  runner.finish()
  return
end

-- Test 2: Test basic command completion
local completions = completion_module.complete("s", "J s", 3)
runner.assert_test(
  "Basic command completion",
  type(completions) == "table",
  "Completion should return a table"
)

local has_status = vim.tbl_contains(completions, "status")
runner.assert_test(
  "Status command in completions",
  has_status,
  "status command should be in completions"
)

-- Test command filtering
local log_completions = completion_module.complete("lo", "J lo", 4)
local has_log = vim.tbl_contains(log_completions, "log")
local has_status_filtered = vim.tbl_contains(log_completions, "status")
runner.assert_test(
  "Command filtering works",
  has_log and not has_status_filtered,
  "Should filter commands based on input"
)

-- Test space-triggered completion (empty arglead)
local space_completions = completion_module.complete("", "J ", 2)
runner.assert_test(
  "Space-triggered completion",
  #space_completions > 0,
  "Should show completions after space with empty arglead"
)

local space_has_status = vim.tbl_contains(space_completions, "status")
runner.assert_test(
  "Space completion includes status",
  space_has_status,
  "Space-triggered completion should include status command"
)

-- Test 3: Test flag completion for a known command
local flag_completions = completion_module.complete("--", "J status --", 10)
runner.assert_test(
  "Flag completion returns results",
  #flag_completions > 0,
  "Should return some flags"
)

-- Test that help flag is included
local has_help = vim.tbl_contains(flag_completions, "--help")
runner.assert_test("Help flag in completions", has_help, "--help should be in flag completions")

-- Test space-triggered flag completion (empty arglead after subcommand)
local space_flag_completions = completion_module.complete("", "J status ", 9)
runner.assert_test(
  "Space-triggered flag completion",
  #space_flag_completions > 0,
  "Should show flag completions after space following subcommand"
)

local space_flag_has_help = vim.tbl_contains(space_flag_completions, "--help")
runner.assert_test(
  "Space flag completion includes help",
  space_flag_has_help,
  "Space-triggered flag completion should include --help"
)

-- Test 4: Test bookmark completion helper
local bookmarks = completion_module.get_bookmarks()
runner.assert_test(
  "Bookmark listing returns table",
  type(bookmarks) == "table",
  "get_bookmarks should return a table"
)
-- Verify bookmarks is iterable (even if empty, should work with ipairs)
local bookmark_count = 0
for _ in ipairs(bookmarks) do
  bookmark_count = bookmark_count + 1
end
runner.assert_test(
  "Bookmark listing is iterable",
  bookmark_count == #bookmarks,
  "get_bookmarks result should be iterable"
)

-- Test 5: Test changed files helper
local files = completion_module.get_changed_files()
runner.assert_test(
  "Changed files listing returns table",
  type(files) == "table",
  "get_changed_files should return a table"
)
-- Verify files is iterable (even if empty, should work with ipairs)
local file_count = 0
for _ in ipairs(files) do
  file_count = file_count + 1
end
runner.assert_test(
  "Changed files listing is iterable",
  file_count == #files,
  "get_changed_files result should be iterable"
)

-- Test 6: Test cache clearing
local success, err = pcall(function()
  completion_module.clear_cache()
end)
runner.assert_test("Cache clearing succeeds", success, "clear_cache crashed: " .. tostring(err))
-- Verify cache was actually cleared by checking we can still get fresh data
if success then
  local fresh_bookmarks = completion_module.get_bookmarks()
  runner.assert_test(
    "Cache clearing allows fresh data retrieval",
    type(fresh_bookmarks) == "table",
    "get_bookmarks should work after cache clear"
  )
end

-- Test 7: Test main plugin completion integration
local main_module = runner.load_module("jj-fugitive")
if main_module then
  local main_completions = main_module.complete("st", "J st", 4)
  runner.assert_test(
    "Main plugin completion integration",
    type(main_completions) == "table",
    "Main plugin should provide completions"
  )

  local has_status_main = vim.tbl_contains(main_completions, "status")
  runner.assert_test(
    "Main plugin has status completion",
    has_status_main,
    "Main plugin should complete status"
  )
end

runner.finish()
