#!/usr/bin/env -S nvim --headless -l

local runner = require("tests.test_runner")
runner.init("Default Log Behavior Tests")

-- Test 1: Module loading
local main_module = runner.load_module("jj-fugitive.init")
if not main_module then
  runner.finish()
  return
end

local log_module = runner.load_module("jj-fugitive.log")
if not log_module then
  runner.finish()
  return
end

runner.section("Test 2: Default jj log behavior")
local default_log = main_module.run_jj_command_from_module({ "log", "--color", "always" })
runner.assert_test("Default log command works", default_log ~= nil, "Default log command failed")

if default_log then
  local default_lines = vim.split(default_log, "\n")
  -- Remove empty lines for accurate count
  local non_empty_lines = runner.count_non_empty_lines(default_log)

  runner.assert_test(
    "Default log shows limited output",
    non_empty_lines <= 10,
    string.format("Expected ≤10 lines, got %d", non_empty_lines)
  )

  -- Check that it contains current working copy (@)
  local has_working_copy = false
  for _, line in ipairs(default_lines) do
    if line:match("@") then
      has_working_copy = true
      break
    end
  end
  runner.assert_test(
    "Default log contains working copy (@)",
    has_working_copy,
    "No @ symbol found in default log"
  )
end

runner.section("Test 3: Full repository log with -r ..")
local full_log = main_module.run_jj_command_from_module({ "log", "--color", "always", "-r", ".." })
runner.assert_test("Full log command works", full_log ~= nil, "Full log command failed")

if full_log then
  local non_empty_full_lines = runner.count_non_empty_lines(full_log)

  runner.assert_test(
    "Full log shows more output",
    non_empty_full_lines > 20,
    string.format("Expected >20 lines, got %d", non_empty_full_lines)
  )
end

runner.section("Test 4: Compare default vs full log behavior")
if default_log and full_log then
  local default_lines = vim.split(default_log, "\n")
  local full_lines = vim.split(full_log, "\n")

  runner.assert_test(
    "Default log is significantly shorter than full log",
    #default_lines < (#full_lines / 2),
    string.format("Default: %d lines, Full: %d lines", #default_lines, #full_lines)
  )
end

runner.section("Test 5: Log module show_log with default options")
log_module.show_log()

-- Check if a log buffer was created
vim.defer_fn(function()
  local log_buffer_found = false
  local log_buffer_lines = 0

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name:match("jj%-log") or name == "" then
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        for _, line in ipairs(lines) do
          if line:match("jj Log View") then
            log_buffer_found = true
            log_buffer_lines = #lines
            break
          end
        end
        if log_buffer_found then
          break
        end
      end
    end
  end

  runner.assert_test("Log buffer created successfully", log_buffer_found, "No log buffer found")
  runner.assert_test(
    "Log buffer contains reasonable amount of content",
    log_buffer_lines > 5 and log_buffer_lines < 50,
    string.format("Expected 5-50 lines, got %d", log_buffer_lines)
  )

  runner.section("Test 6: Expand functionality available")
  if log_buffer_found then
    -- Check that buffer has expand keymaps
    local current_buf = vim.api.nvim_get_current_buf()
    local keymaps = vim.api.nvim_buf_get_keymap(current_buf, "n")
    local has_expand_keymap = false
    for _, keymap in ipairs(keymaps) do
      if keymap.lhs == "=" or keymap.lhs == "+" then
        has_expand_keymap = true
        break
      end
    end
    runner.assert_test(
      "Expand keymaps available",
      has_expand_keymap,
      "No expand keymaps (= or +) found"
    )
  end

  local additional_summary = {
    "",
    "Key behaviors verified:",
    "  ✅ Default :J log shows standard jj log output (recent commits)",
    "  ✅ Full repository history available via expand functionality",
    "  ✅ Default log is significantly shorter than full repo log",
    "  ✅ Expand keymaps (= and +) available for showing more commits",
    "  ✅ Log buffer creation works with new default behavior",
  }

  runner.finish(additional_summary)
end, 100)

-- Keep running for the defer_fn
vim.loop.run("default")
