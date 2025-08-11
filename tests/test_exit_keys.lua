#!/usr/bin/env -S nvim --headless -l

local runner = require("tests.test_runner")

runner.init("jj-fugitive Back/Quit Key Abstraction Tests")

local ui = runner.load_module("jj-fugitive.ui")
local status_module = runner.load_module("jj-fugitive.status")
local log_module = runner.load_module("jj-fugitive.log")
local diff_module = runner.load_module("jj-fugitive.diff")

runner.section("API availability")
runner.check_function(ui, "setup_exit_keymaps", "UI module")
runner.check_function(ui, "go_back_or_close", "UI module")

runner.section("Status view exit keys")
if status_module then
  pcall(status_module.show_status)
  local status_buf = runner.find_buffer("jj%-status")
  runner.assert_test("Status buffer exists", status_buf ~= nil, "Status buffer should exist")
  if status_buf then
    local keymaps = vim.api.nvim_buf_get_keymap(status_buf, "n")
    local want = { q = false, b = false, gq = false }
    for _, km in ipairs(keymaps) do
      if km.lhs == "q" then want.q = true end
      if km.lhs == "b" then want.b = true end
      if km.lhs == "gq" then want.gq = true end
    end
    runner.assert_test("Status 'q' mapped", want.q, "q should close status")
    runner.assert_test("Status 'b' mapped", want.b, "b should close status")
    runner.assert_test("Status 'gq' mapped", want.gq, "gq should close status")
  end
end

runner.section("Log view exit keys")
if log_module then
  pcall(function() log_module.show_log({ limit = 5 }) end)
  local log_buf = runner.find_buffer("jj%-log")
  runner.assert_test("Log buffer exists", log_buf ~= nil, "Log buffer should exist")
  if log_buf then
    local keymaps = vim.api.nvim_buf_get_keymap(log_buf, "n")
    local want = { q = false, b = false }
    for _, km in ipairs(keymaps) do
      if km.lhs == "q" then want.q = true end
      if km.lhs == "b" then want.b = true end
    end
    runner.assert_test("Log 'q' mapped", want.q, "q should close log")
    runner.assert_test("Log 'b' mapped", want.b, "b should close log")
  end
end

runner.section("Diff view back behavior from status")
if diff_module and status_module then
  -- Ensure we're on status buffer first
  pcall(status_module.show_status)
  local test_file = "exit_keys_test.txt"
  local created = runner.create_test_file(test_file, "Back/close test content\n")
  if created then
    -- Open diff in current jj buffer and mark previous view
    pcall(function()
      diff_module.show_file_diff(test_file, { update_current = true, previous_view = "status" })
    end)
    local cur = vim.api.nvim_get_current_buf()
    local has_prev = pcall(vim.api.nvim_buf_get_var, cur, "jj_previous_view")
    runner.assert_test("Diff has previous_view set", has_prev, "jj_previous_view should be set")

    -- b should go back to status via helper
    pcall(function()
      ui.go_back_or_close(cur)
    end)
    local status_buf = runner.find_buffer("jj%-status")
    runner.assert_test("Returned to status view", status_buf ~= nil, "Should find status buffer after back")

    pcall(function() os.remove(test_file) end)
  end
end

runner.section("Commit details back behavior to log")
if log_module then
  -- Open a log buffer first to ensure jj buffer
  pcall(function() log_module.show_log({ limit = 3 }) end)
  -- Grab a recent commit id
  local out = vim.fn.system({ "jj", "log", "--limit", "1", "--no-graph" })
  local commit = out and out:match("([a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9])")
  if commit then
    pcall(function() log_module.show_commit_details(commit, { update_current = true }) end)
    local cur = vim.api.nvim_get_current_buf()
    local keymaps = vim.api.nvim_buf_get_keymap(cur, "n")
    local has_b = false
    for _, km in ipairs(keymaps) do
      if km.lhs == "b" then has_b = true end
    end
    runner.assert_test("Commit details 'b' mapped", has_b, "b should be mapped in commit details")
    -- simulate back
    pcall(function() ui.go_back_or_close(cur) end)
    local log_buf = runner.find_buffer("jj%-log")
    runner.assert_test("Returned to log view", log_buf ~= nil, "Should find log buffer after back")
  else
    runner.skip("Commit extraction", "No commit id obtained")
  end
end

runner.finish()

