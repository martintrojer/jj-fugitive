#!/usr/bin/env -S nvim --headless -l

local runner = require("tests.test_runner")

runner.init("jj-fugitive Log Functionality Tests")

local log_module = runner.load_module("jj-fugitive.log")

-- Test help command first to get version info
local help_output = vim.fn.system("jj --help")
print(help_output:match("Jujutsu [^\n]*") or "")

-- Test 1: Basic log functionality
runner.check_function(log_module, "show_log", "Log module")

if log_module then
  local success = pcall(function()
    log_module.show_log({ limit = 5 })
  end)
  runner.assert_test("Log view creation", success, "show_log should work without errors")
end

-- Test 2: Log buffer verification
local log_bufnr = runner.find_buffer("jj%-log")
runner.assert_test("Log buffer created", log_bufnr ~= nil, "Log buffer should be created")

if log_bufnr then
  -- Test buffer properties
  local buftype = vim.api.nvim_buf_get_option(log_bufnr, "buftype")
  runner.assert_test(
    "Log buffer has correct buftype",
    buftype == "nofile",
    "Log buffer should be nofile type"
  )

  local modifiable = vim.api.nvim_buf_get_option(log_bufnr, "modifiable")
  runner.assert_test(
    "Log buffer is not modifiable",
    not modifiable,
    "Log buffer should not be modifiable"
  )

  -- Test buffer content
  local content = vim.api.nvim_buf_get_lines(log_bufnr, 0, -1, false)
  local has_content = #content > 0
  runner.assert_test(
    "Log buffer has content",
    has_content,
    "Log buffer should contain log information"
  )

  local content_str = table.concat(content, "\n")
  local has_header = content_str:match("jj Log View") or content_str:match("Navigate:")
  runner.assert_test(
    "Log buffer has header",
    has_header,
    "Log buffer should contain header information"
  )

  -- Test for commit information
  local has_commits = content_str:match("@") or content_str:match("◆") or content_str:match("○")
  runner.assert_test(
    "Log buffer contains commits",
    has_commits,
    "Log buffer should show commit information"
  )
end

-- Test 3: Log keybindings
if log_bufnr then
  local keymaps = vim.api.nvim_buf_get_keymap(log_bufnr, "n")
  local has_enter_key = false
  local has_q_key = false
  local has_expand_key = false

  for _, keymap in ipairs(keymaps) do
    if keymap.lhs == "<CR>" then
      has_enter_key = true
    end
    if keymap.lhs == "q" then
      has_q_key = true
    end
    if keymap.lhs == "=" or keymap.lhs == "+" then
      has_expand_key = true
    end
  end

  runner.assert_test(
    "Enter key mapping exists",
    has_enter_key,
    "Log buffer should have Enter key mapping"
  )

  runner.assert_test("Quit key mapping exists", has_q_key, "Log buffer should have 'q' key mapping")

  runner.assert_test(
    "Expand key mapping exists",
    has_expand_key,
    "Log buffer should have expand key mapping"
  )
end

-- Test 4: jj log command integration
local jj_log_output = vim.fn.system({ "jj", "log", "--limit", "5" })
runner.assert_test(
  "jj log command works",
  jj_log_output ~= nil and jj_log_output ~= "",
  "jj log command should produce output"
)

local has_log_commits = jj_log_output:match("@")
  or jj_log_output:match("◆")
  or jj_log_output:match("○")
runner.assert_test("jj log shows commits", has_log_commits, "jj log should show commit information")

-- Test 5: Log with different options
if log_module then
  local success_limited, err = pcall(function()
    log_module.show_log({ limit = 10, update_current = true })
  end)
  runner.assert_test(
    "Log with limit option",
    success_limited,
    "show_log should work with limit option" .. (err and (": " .. tostring(err)) or "")
  )
end

runner.finish()
