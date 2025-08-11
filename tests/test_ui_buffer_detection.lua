#!/usr/bin/env -S nvim --headless -l

local runner = require("tests.test_runner")

runner.init("jj-fugitive UI Safety Tests")

local ui = runner.load_module("jj-fugitive.ui")
local log = runner.load_module("jj-fugitive.log")
local status = runner.load_module("jj-fugitive.status")

-- Show log view and verify plugin buffer flag
if log then
  local ok = pcall(function()
    log.show_log({ update_current = false })
  end)
  runner.assert_test("Log view creation", ok, "log.show_log should not error")
end

local log_buf = runner.find_buffer("jj%-log")
runner.assert_test("Log buffer exists", log_buf ~= nil, "jj-log buffer should be present")
if log_buf then
  local is_plugin = ui.is_jj_buffer(log_buf)
  runner.assert_test(
    "Log buffer marked as plugin",
    is_plugin == true,
    "jj-log buffer should be flagged"
  )
end

-- Help popup should NOT be treated as plugin buffer
do
  local help_buf, help_win = ui.show_help_popup(
    "Test Help",
    { "Line 1", "Line 2" },
    { width = 40, height = 5 }
  )
  local is_plugin = ui.is_jj_buffer(help_buf)
  runner.assert_test(
    "Help buffer not plugin",
    is_plugin == false,
    "help popup should not be flagged as plugin"
  )
  if help_win and vim.api.nvim_win_is_valid(help_win) then
    vim.api.nvim_win_close(help_win, true)
  end
end

-- Plain scratch buffer should NOT be treated as plugin buffer
do
  local scratch = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(scratch, "plain-scratch")
  local is_plugin = ui.is_jj_buffer(scratch)
  runner.assert_test(
    "Scratch buffer not plugin",
    is_plugin == false,
    "plain scratch should not be flagged"
  )
end

-- update_current from non-plugin buffer should not try to update it
do
  -- Create and switch to a plain buffer
  local plain = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(plain)
  vim.api.nvim_buf_set_name(plain, "plain-current")

  -- Invoke log with update_current=true
  local ok = pcall(function()
    log.show_log({ update_current = true })
  end)
  runner.assert_test(
    "update_current from non-plugin ok",
    ok,
    "show_log(update_current) should not error"
  )

  -- Original plain buffer must remain not flagged as plugin
  local is_plugin = ui.is_jj_buffer(plain)
  runner.assert_test(
    "Original plain buffer intact",
    is_plugin == false,
    "non-plugin buffer should remain unflagged after update_current"
  )
end

-- Status buffer should be flagged as plugin buffer
if status then
  local ok = pcall(function()
    status.show_status()
  end)
  runner.assert_test("Status view creation", ok, "status.show_status should not error")
end

local status_buf = runner.find_buffer("jj%-status")
runner.assert_test("Status buffer exists", status_buf ~= nil, "jj-status buffer should be present")
if status_buf then
  local is_plugin = ui.is_jj_buffer(status_buf)
  runner.assert_test(
    "Status buffer marked as plugin",
    is_plugin == true,
    "jj-status buffer should be flagged"
  )
end

runner.finish()
