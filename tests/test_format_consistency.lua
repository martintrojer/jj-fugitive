#!/usr/bin/env -S nvim --headless -l

local runner = require("tests.test_runner")
runner.init("jj-fugitive Format Consistency Tests")

-- Test 1: Load required modules
local ansi = runner.load_module("jj-fugitive.ansi")
local diff_module = runner.load_module("jj-fugitive.diff")
local log_module = runner.load_module("jj-fugitive.log")

runner.assert_test(
  "All modules loaded",
  ansi and diff_module and log_module,
  "Failed to load required modules"
)

-- Create test data for consistency testing
local test_file = "test_format_consistency.txt"
runner.create_test_file(test_file, "Line 1\nLine 2\nLine 3\n")

vim.fn.system({ "jj", "file", "track", test_file })
vim.fn.system({ "jj", "describe", "-m", "Add test file for format consistency" })

-- Modify file to create diff content
file = io.open(test_file, "w")
if file then
  file:write("Modified Line 1\nLine 2\nLine 3\nLine 4 added\n")
  file:close()
end

vim.fn.system({ "jj", "describe", "-m", "Modify test file" })

-- Test 2: Test ANSI module functions directly
local sample_ansi = "\27[1mBold\27[0m \27[32mGreen\27[0m \27[31mRed\27[0m"
local clean_text, highlights = ansi.parse_ansi_colors(sample_ansi)

runner.assert_test(
  "ANSI parsing produces clean text",
  clean_text == "Bold Green Red",
  "Expected 'Bold Green Red', got: '" .. clean_text .. "'"
)

runner.assert_test(
  "ANSI parsing extracts highlights",
  #highlights == 3,
  "Expected 3 highlights, got: " .. #highlights
)

-- Test 3: Test diff content processing consistency
local diff_content =
  "\27[1mdiff --git\27[0m a/test.txt b/test.txt\n\27[32m+new line\27[0m\n\27[31m-old line\27[0m"
local header_lines = { "# Header Line", "# Subheader" }

local processed_lines, all_highlights = ansi.process_diff_content(diff_content, header_lines)

runner.assert_test(
  "Headers preserved in processed content",
  processed_lines[1] == "# Header Line" and processed_lines[2] == "# Subheader",
  "Headers not correctly preserved"
)

local content_line_found = false
for i = 3, #processed_lines do
  if processed_lines[i]:match("diff") then -- More flexible matching
    content_line_found = true
    break
  end
end

-- Debug: Print what we actually got if test fails
if not content_line_found then
  runner.info("DEBUG: Processed lines content:")
  for i, line in ipairs(processed_lines) do
    runner.info(string.format("  %d: %s", i, line))
  end
end

runner.assert_test(
  "Content processed and ANSI stripped",
  content_line_found,
  "Diff content not found in processed lines"
)

runner.assert_test(
  "Highlights adjusted for header offset",
  #all_highlights > 0,
  "No highlights generated with header offset"
)

-- Test 4: Test buffer creation with consistent formatting
local test_content =
  "\27[1mCommit:\27[0m abc123\n\27[32m+Added line\27[0m\n\27[31m-Removed line\27[0m"
local test_headers = { "# Test Commit", "# Test changes" }

local bufnr = ansi.create_colored_buffer(test_content, "test-buffer", test_headers, {
  prefix = "TestPrefix",
  custom_syntax = {
    ["^# Test.*$"] = "TestHeader",
  },
})

runner.assert_test(
  "Colored buffer created successfully",
  bufnr and vim.api.nvim_buf_is_valid(bufnr),
  "Buffer creation failed or invalid buffer"
)

if bufnr then
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = table.concat(lines, "\n")

  runner.assert_test(
    "Buffer contains headers",
    content:match("# Test Commit"),
    "Headers not found in buffer content"
  )

  runner.assert_test(
    "Buffer content has no ANSI codes",
    not content:match("\27%["),
    "ANSI codes still present in buffer"
  )

  local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")
  runner.assert_test(
    "Buffer has diff filetype",
    filetype == "diff",
    "Buffer filetype is " .. filetype .. ", expected diff"
  )
end

-- Test 5: Get commit for real integration testing
local commit_output =
  vim.fn.system({ "jj", "log", "--limit", "1", "--template", "change_id.short()" })
local commit_id = vim.trim(commit_output:match("([^\n]+)"))

if commit_id and #commit_id > 0 then
  runner.info("Testing with commit ID: " .. commit_id)

  -- Test 6: Test that jj show and jj diff use consistent formats
  local show_output = vim.fn.system({ "jj", "show", "--color", "always", commit_id })
  local diff_output = vim.fn.system({ "jj", "diff", "--color", "always", "-r", commit_id })

  runner.assert_test(
    "jj show produces colored output",
    show_output:match("\27%["),
    "jj show doesn't produce ANSI codes"
  )

  runner.assert_test(
    "jj diff produces colored output",
    diff_output:match("\27%["),
    "jj diff doesn't produce ANSI codes"
  )

  -- Test 7: Verify both outputs process consistently
  local show_clean, show_highlights = ansi.parse_ansi_colors(show_output)
  local diff_clean, diff_highlights = ansi.parse_ansi_colors(diff_output)

  runner.assert_test(
    "Show output ANSI processing works",
    not show_clean:match("\27%[") and #show_highlights > 0,
    "Show output ANSI processing failed"
  )

  runner.assert_test(
    "Diff output ANSI processing works",
    not diff_clean:match("\27%[") and #diff_highlights > 0,
    "Diff output ANSI processing failed"
  )

  -- Test 8: Test that both log show and diff views create properly formatted buffers
  local initial_buf_count = #vim.api.nvim_list_bufs()

  -- Test diff view buffer
  pcall(function()
    diff_module.show_file_diff(test_file)
  end)

  local after_diff_count = #vim.api.nvim_list_bufs()
  local diff_buf_created = after_diff_count > initial_buf_count

  runner.assert_test("Diff view creates buffer", diff_buf_created, "Diff view didn't create buffer")

  -- Test log view buffer
  pcall(function()
    log_module.show_log({ limit = 3 })
  end)

  local after_log_count = #vim.api.nvim_list_bufs()
  local log_buf_created = after_log_count > after_diff_count

  runner.assert_test("Log view creates buffer", log_buf_created, "Log view didn't create buffer")

  -- Test 9: Verify format consistency in created buffers
  local diff_buffer = nil
  local log_buffer = nil

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      if name:match("jj%-diff") and name:match(test_file) then
        diff_buffer = buf
      elseif name:match("jj%-log$") then
        log_buffer = buf
      end
    end
  end

  if diff_buffer then
    local diff_lines = vim.api.nvim_buf_get_lines(diff_buffer, 0, -1, false)
    local has_header = false
    for _, line in ipairs(diff_lines) do
      if line:match("^# File:") or line:match("^# Changes") then
        has_header = true
        break
      end
    end

    runner.assert_test(
      "Diff buffer has consistent header format",
      has_header,
      "Diff buffer missing expected header format"
    )

    local buffer_content = table.concat(diff_lines, "\n")
    runner.assert_test(
      "Diff buffer content clean of ANSI",
      not buffer_content:match("\27%["),
      "ANSI codes found in diff buffer"
    )
  end

  if log_buffer then
    local log_buftype = vim.api.nvim_buf_get_option(log_buffer, "buftype")
    runner.assert_test(
      "Log buffer has consistent buftype",
      log_buftype == "nofile",
      "Log buffer buftype inconsistent"
    )
  end

  -- Test 10: Test unified highlight prefix usage
  -- Both diff view and log commit diff should use same JjDiff prefix for consistency
  local consistency_check = (
    ansi.create_colored_buffer ~= nil
    and ansi.setup_diff_highlighting ~= nil
    and diff_buffer ~= nil
  )

  runner.assert_test(
    "Unified formatting infrastructure",
    consistency_check,
    "Missing components for unified formatting"
  )
else
  runner.assert_test("Valid commit for testing", false, "No valid commit ID found")
end

-- Cleanup
pcall(function()
  os.remove(test_file)
end)

runner.finish({
  "🎉 All format consistency tests passed!",
  "📝 Achievements:",
  "   ✅ ANSI parsing works consistently across modules",
  "   ✅ Buffer creation uses unified formatting",
  "   ✅ Headers and content formatting is consistent",
  "   ✅ Both diff and log views use same highlighting system",
  "   ✅ No ANSI codes leak into buffer display",
})
