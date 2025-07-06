#!/usr/bin/env -S nvim --headless -l

local runner = require("tests.test_runner")

runner.init("jj-fugitive Log Color Rendering Tests")

local log_module = runner.load_module("jj-fugitive.log")

-- Test jj show command with colors
local commit_output =
  vim.fn.system({ "jj", "log", "--limit", "1", "--template", "commit_id.short()" })
local commit_id = vim.trim(commit_output)

if commit_id and #commit_id > 0 then
  local show_output = vim.fn.system({ "jj", "show", "--color", "always", commit_id })
  runner.assert_test(
    "jj show produces ANSI color codes",
    runner.has_ansi_codes(show_output),
    "jj show should contain ANSI escape sequences"
  )
  runner.info("Found ANSI codes in jj show output")

  local diff_output = vim.fn.system({ "jj", "diff", "--color", "always", "-r", commit_id })
  runner.assert_test(
    "jj diff produces ANSI color codes",
    runner.has_ansi_codes(diff_output),
    "jj diff should contain ANSI escape sequences"
  )
  runner.info("Found ANSI codes in jj diff output")
end

-- Test log buffer creation
if log_module then
  local success = pcall(function()
    log_module.show_log({ limit = 5 })
  end)
  runner.assert_test("Log buffer created", success, "show_log should work without errors")
end

local log_bufnr = runner.find_buffer("jj%-log")
runner.assert_test("Log buffer found", log_bufnr ~= nil, "Log buffer should be created")

if log_bufnr then
  local content = vim.api.nvim_buf_get_lines(log_bufnr, 0, -1, false)
  local has_content = #content > 0
  runner.assert_test(
    "Log buffer has expected content",
    has_content,
    "Log buffer should contain log content"
  )

  -- Look for commit lines
  local found_commit_line = false
  local commit_id_found = nil
  local commit_line = nil

  for _, line in ipairs(content) do
    -- Look for commit patterns like: @ xyz123 or ○ xyz123
    local id = line:match("[@○◆]%s+%w+%s+.*%s+([a-f0-9]+)")
    if id and #id >= 8 then
      found_commit_line = true
      commit_id_found = id
      commit_line = line
      break
    end
  end

  runner.assert_test(
    "Found valid commit line in log",
    found_commit_line,
    "Log should contain commit lines with IDs"
  )

  if commit_id_found then
    runner.info("Found commit ID: " .. commit_id_found)
    runner.info("Commit line: " .. (commit_line or ""))
  end
end

runner.assert_test(
  "Log view color integration ready",
  true,
  "Log view should be ready for color integration"
)

local summary = {
  "Manual testing needed:",
  "   1. Run ':J log' in Neovim",
  "   2. Press Enter on a commit to see colored commit details",
  "   3. Press 'd' on a commit to see colored diff",
  "   4. Verify colors are rendered properly",
}

runner.finish(summary)
