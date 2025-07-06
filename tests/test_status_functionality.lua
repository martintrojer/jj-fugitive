#!/usr/bin/env -S nvim --headless -l

local runner = require("tests.test_runner")

runner.init("jj-fugitive Status Functionality Tests")

local status_module = runner.load_module("jj-fugitive.status")

-- Test 1: Status module loading and basic function availability
runner.check_function(status_module, "show_status", "Status module")

-- Test 2: Basic status command functionality
if status_module then
  local success = pcall(function()
    status_module.show_status()
  end)
  runner.assert_test("Status view creation", success, "show_status should work without errors")
end

-- Test 3: Status buffer verification
local status_bufnr = runner.find_buffer("jj%-status")
runner.assert_test("Status buffer created", status_bufnr ~= nil, "Status buffer should be created")

if status_bufnr then
  -- Test buffer properties
  local buftype = vim.api.nvim_buf_get_option(status_bufnr, "buftype")
  runner.assert_test(
    "Status buffer has correct buftype",
    buftype == "nofile",
    "Status buffer should be nofile type"
  )

  local modifiable = vim.api.nvim_buf_get_option(status_bufnr, "modifiable")
  runner.assert_test(
    "Status buffer is not modifiable",
    not modifiable,
    "Status buffer should not be modifiable"
  )

  -- Test buffer content
  local content = vim.api.nvim_buf_get_lines(status_bufnr, 0, -1, false)
  local has_content = #content > 0
  runner.assert_test(
    "Status buffer has content",
    has_content,
    "Status buffer should contain status information"
  )

  local content_str = table.concat(content, "\n")
  local has_header = content_str:match("jj%-fugitive") or content_str:match("Status")
  runner.assert_test(
    "Status buffer has header",
    has_header,
    "Status buffer should contain header information"
  )

  -- Test for working copy information
  local has_working_copy = content_str:match("Working copy") or content_str:match("@")
  runner.assert_test(
    "Status buffer contains working copy info",
    has_working_copy,
    "Status buffer should show working copy information"
  )
end

-- Test 4: Status keybindings
if status_bufnr then
  local keymaps = vim.api.nvim_buf_get_keymap(status_bufnr, "n")
  local has_enter_key = false
  local has_q_key = false
  local has_r_key = false

  for _, keymap in ipairs(keymaps) do
    if keymap.lhs == "<CR>" then
      has_enter_key = true
    end
    if keymap.lhs == "q" then
      has_q_key = true
    end
    if keymap.lhs == "R" then
      has_r_key = true
    end
  end

  runner.assert_test(
    "Enter key mapping exists",
    has_enter_key,
    "Status buffer should have Enter key mapping"
  )

  runner.assert_test(
    "Quit key mapping exists",
    has_q_key,
    "Status buffer should have 'q' key mapping"
  )

  runner.assert_test(
    "Reload key mapping exists",
    has_r_key,
    "Status buffer should have 'R' key mapping"
  )
end

-- Test 5: jj status command integration
local jj_status_output = vim.fn.system({ "jj", "status" })
runner.assert_test(
  "jj status command works",
  jj_status_output ~= nil and jj_status_output ~= "",
  "jj status command should produce output"
)

-- Test 6: Status parsing and formatting
local has_working_copy_info = jj_status_output:match("Working copy") or jj_status_output:match("@")
runner.assert_test(
  "jj status shows working copy",
  has_working_copy_info,
  "jj status should show working copy information"
)

runner.finish()
