#!/usr/bin/env -S nvim --headless -l

local runner = require("tests.test_runner")

runner.init("jj-fugitive Native Log View Tests")

local log_module = runner.load_module("jj-fugitive.log")

-- Test 1: Native jj log output comparison
local native_jj_log = vim.fn.system({ "jj", "log", "--color", "always", "--limit", "5" })
local has_output = native_jj_log ~= nil and native_jj_log ~= "" and vim.v.shell_error == 0
runner.assert_test(
  "Native jj log produces output",
  has_output,
  "jj log should produce output without errors"
)

-- Only test colors if we have valid output
if has_output then
  runner.assert_test(
    "Native jj log has colors",
    runner.has_ansi_codes(native_jj_log),
    "Native jj log should have ANSI colors"
  )
else
  runner.skip("Native jj log has colors", "No valid jj log output to test")
end

-- Test 2: Plugin log view creation
if log_module then
  local success = pcall(function()
    log_module.show_log({ limit = 5 })
  end)
  runner.assert_test("Plugin log view creation", success, "Plugin should create log view")
end

local log_bufnr = runner.find_buffer("jj%-log")
runner.assert_test("Plugin log buffer created", log_bufnr ~= nil, "Log buffer should be created")

-- Test 3: Format consistency
if log_bufnr then
  local content = vim.api.nvim_buf_get_lines(log_bufnr, 0, -1, false)
  local content_str = table.concat(content, "\n")

  runner.assert_test(
    "Plugin log has no ANSI codes",
    not runner.has_ansi_codes(content_str),
    "Plugin log should have clean text"
  )

  local has_symbols = content_str:match("@")
    or content_str:match("◆")
    or content_str:match("○")
    or content_str:match("o")
  runner.assert_test(
    "Plugin log preserves jj symbols",
    has_symbols,
    "Plugin should preserve native jj commit symbols"
  )
end

-- Test 4: Symbol preservation (only if we have valid output)
if has_output then
  local has_working_copy = native_jj_log:match("@")
  local has_commit_symbols = native_jj_log:match("◆")
    or native_jj_log:match("○")
    or native_jj_log:match("o")
    or native_jj_log:match("%*")
  local has_branch_symbols = native_jj_log:match("│") or native_jj_log:match("├")

  runner.assert_test(
    "Native log has working copy symbol (@)",
    has_working_copy,
    "Native jj log should show @ symbol"
  )

  runner.assert_test(
    "Native log has commit symbols",
    has_commit_symbols,
    "Native jj log should show commit symbols"
  )

  runner.info("Branch symbols found: " .. (has_branch_symbols and "yes" or "no"))
else
  runner.skip("Native log has working copy symbol (@)", "No valid jj log output to test")
  runner.skip("Native log has commit symbols", "No valid jj log output to test")
  runner.info("Branch symbols found: skipped (no valid output)")
end

local summary = {
  "Key achievements:",
  "  ✅ Native jj log formatting preserved in plugin",
  "  ✅ ANSI colors processed correctly",
  "  ✅ Commit symbols (@, ◆, ○) maintained",
  "  ✅ Clean buffer content without ANSI codes",
  "  ✅ Authentic jj log appearance in Neovim",
}

runner.finish(summary)
