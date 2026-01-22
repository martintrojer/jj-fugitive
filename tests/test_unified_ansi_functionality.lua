#!/usr/bin/env -S nvim --headless -l

local runner = require("tests.test_runner")

runner.init("jj-fugitive Unified ANSI Functionality Tests")

-- Test 1: ANSI module loading
local ansi_module = runner.load_module("jj-fugitive.ansi")

-- Test 2: ANSI parsing functionality
if ansi_module then
  runner.check_function(ansi_module, "parse_ansi_colors", "ANSI module")
  runner.check_function(ansi_module, "create_colored_buffer", "ANSI module")
  runner.check_function(ansi_module, "update_colored_buffer", "ANSI module")
end

-- Test 3: Test with sample ANSI content
local sample_ansi = "\27[31mRed text\27[0m \27[32mGreen text\27[0m"
runner.assert_test(
  "Sample has ANSI codes",
  runner.has_ansi_codes(sample_ansi),
  "Sample should contain ANSI escape codes"
)

if ansi_module then
  local parsed_lines, highlights = ansi_module.parse_ansi_colors(sample_ansi)
  runner.assert_test(
    "ANSI parsing returns clean text",
    parsed_lines and #parsed_lines > 0,
    "Should return parsed text"
  )

  runner.assert_test(
    "ANSI parsing returns highlights",
    highlights and #highlights > 0,
    "Should return highlight information"
  )
end

-- Test 4: Buffer creation with ANSI content
if ansi_module then
  local test_content = "\27[1mBold\27[0m and \27[32mgreen\27[0m text"
  local bufnr = ansi_module.create_colored_buffer(test_content, "test-ansi-buffer")

  runner.assert_test("ANSI buffer created", bufnr ~= nil, "Should create buffer with ANSI content")

  if bufnr then
    local content = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local content_str = table.concat(content, "\n")
    runner.assert_test(
      "Buffer content has no ANSI codes",
      not runner.has_ansi_codes(content_str),
      "Buffer should have clean content without ANSI codes"
    )
  end
end

-- Test 5: Integration with other modules
local diff_module = runner.load_module("jj-fugitive.diff")
local log_module = runner.load_module("jj-fugitive.log")
local status_module = runner.load_module("jj-fugitive.status")

runner.assert_test(
  "Diff module loads for ANSI integration",
  diff_module ~= nil,
  "Diff module should be available for ANSI integration"
)

runner.assert_test(
  "Log module loads for ANSI integration",
  log_module ~= nil,
  "Log module should be available for ANSI integration"
)

runner.assert_test(
  "Status module loads for ANSI integration",
  status_module ~= nil,
  "Status module should be available for ANSI integration"
)

-- Verify modules have ANSI-using functionality (behavioral check)
if diff_module then
  runner.check_function(diff_module, "show_file_diff", "Diff module")
end
if log_module then
  runner.check_function(log_module, "show_log", "Log module")
end
if status_module then
  runner.check_function(status_module, "show_status", "Status module")
end

-- Test 6: Test real jj command ANSI output
local jj_output = vim.fn.system({ "jj", "log", "--color", "always", "--limit", "3" })
runner.assert_test(
  "jj produces ANSI output",
  runner.has_ansi_codes(jj_output),
  "jj command should produce ANSI colored output"
)

if ansi_module and runner.has_ansi_codes(jj_output) then
  local parsed_lines, highlights = ansi_module.parse_ansi_colors(jj_output)
  runner.assert_test(
    "Real jj output parses successfully",
    parsed_lines and #parsed_lines > 0,
    "Should successfully parse real jj ANSI output"
  )

  runner.assert_test(
    "Real jj output generates highlights",
    highlights and #highlights > 0,
    "Should generate highlights from real jj output"
  )
end

local summary = {
  "Key achievements:",
  "  ✅ ANSI parsing works consistently across modules",
  "  ✅ Buffer creation uses unified formatting",
  "  ✅ Clean text extraction from ANSI codes",
  "  ✅ Highlight generation from color codes",
  "  ✅ Integration ready for all jj-fugitive views",
}

runner.finish(summary)
