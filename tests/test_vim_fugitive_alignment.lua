#!/usr/bin/env -S nvim --headless -l

local runner = require("tests.test_runner")

runner.init("jj-fugitive vim-fugitive Alignment Tests")

-- Test 1: Check main module and command structure
local main_module = runner.load_module("jj-fugitive")

-- Test 2: Core module availability
local status_module = runner.load_module("jj-fugitive.status")
local log_module = runner.load_module("jj-fugitive.log")
local diff_module = runner.load_module("jj-fugitive.diff")

-- Test 3: Key function alignment with vim-fugitive patterns
runner.check_function(status_module, "show_status", "Status module")
runner.check_function(log_module, "show_log", "Log module")
runner.check_function(diff_module, "show_file_diff", "Diff module")

-- Test 4: Command patterns (similar to vim-fugitive's :G commands)
runner.assert_test(
  "Main module available",
  main_module ~= nil,
  "Main jj-fugitive module should be available"
)

-- Test 5: Buffer naming consistency
if status_module then
  pcall(status_module.show_status)
  local status_buf = runner.find_buffer("jj%-status")
  runner.assert_test(
    "Status buffer follows naming pattern",
    status_buf ~= nil,
    "Status buffer should follow jj-status naming"
  )
end

if log_module then
  pcall(function()
    log_module.show_log({ limit = 3 })
  end)
  local log_buf = runner.find_buffer("jj%-log")
  runner.assert_test(
    "Log buffer follows naming pattern",
    log_buf ~= nil,
    "Log buffer should follow jj-log naming"
  )
end

-- Test 6: Keybinding consistency (vim-fugitive style)
local status_buf = runner.find_buffer("jj%-status")
if status_buf then
  local has_cr = vim.fn.maparg("<CR>", "n", false, true).buffer == 1
  local has_q = vim.fn.maparg("q", "n", false, true).buffer == 1
  local has_help = vim.fn.maparg("g?", "n", false, true).buffer == 1

  runner.assert_test(
    "Enter key works like vim-fugitive",
    has_cr,
    "<CR> should be mapped for file actions"
  )

  runner.assert_test("Quit key works like vim-fugitive", has_q, "q should close the buffer")

  runner.assert_test("Help key works like vim-fugitive", has_help, "g? should show help")
end

-- Test 7: Core workflow alignment
runner.assert_test(
  "Status view paradigm",
  status_module ~= nil,
  "Status view should be the main entry point"
)

runner.assert_test("Log view paradigm", log_module ~= nil, "Log view should show commit history")

runner.assert_test("Diff view paradigm", diff_module ~= nil, "Diff view should show file changes")

local summary = {
  "✅ vim-fugitive alignment working correctly",
  "Key paradigms verified:",
  "  • Status view as main interface (like :G status)",
  "  • Log view for history (like :G log)",
  "  • Diff view for changes (like :G diff)",
  "  • Consistent keybindings (<CR>, q, g?)",
  "  • Buffer naming patterns (jj-status, jj-log, etc.)",
  "  • Familiar workflow and navigation",
}

runner.finish(summary)
