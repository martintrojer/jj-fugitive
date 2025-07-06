#!/usr/bin/env -S nvim --headless -l

local runner = require("tests.test_runner")
runner.init("jj-fugitive Color Rendering Tests")

-- Add CI environment debugging
if runner.is_ci() then
  runner.section("CI Environment Information")
  runner.info("Working directory: " .. vim.fn.getcwd())
  runner.info(
    "Neovim version: "
      .. vim.version().major
      .. "."
      .. vim.version().minor
      .. "."
      .. vim.version().patch
  )
end

runner.section("Module Loading")
-- Test 1: Check if diff module can be loaded
local diff_module = runner.load_module("jj-fugitive.diff")

runner.section("Test File Creation")
-- Create test file with changes to generate colored diff
local test_file = "test_color_rendering.txt"
runner.create_test_file(test_file, "Line 1\nLine 2\nLine 3\n")

runner.section("File Tracking")
-- Check jj version and track file if needed
local version_output = vim.fn.system({ "jj", "--version" })
local has_file_cmd = version_output and version_output:match("jj 0%.1[6-9]")
  or version_output:match("jj 0%.[2-9]")
  or version_output:match("jj [1-9]")

if has_file_cmd then
  -- Track the file in newer jj versions
  local track_result = vim.fn.system({ "jj", "file", "track", test_file })
  local track_exit_code = vim.v.shell_error
  if track_exit_code ~= 0 then
    if runner.is_ci() then
      runner.info("jj file track failed with exit code: " .. track_exit_code)
      runner.info("Output: " .. track_result)
    end
  end
else
  -- Older jj versions auto-track files
  if runner.is_ci() then
    runner.info("Using jj v0.15.x - files are auto-tracked")
  end
end

-- Modify the file to create additions and deletions
local modified_file = io.open(test_file, "w")
if modified_file then
  modified_file:write("Line 1 modified\nLine 2\nLine 4 added\n")
  modified_file:close()
end

runner.section("ANSI Color Code Detection")
-- Test 2: Get colored diff output
local jj_diff_colored = vim.fn.system({ "jj", "diff", "--color", "always", test_file })
local diff_exit_code = vim.v.shell_error
if diff_exit_code ~= 0 then
  if runner.is_ci() then
    runner.info("jj diff failed with exit code: " .. diff_exit_code)
    runner.info("Output: " .. jj_diff_colored)
  end
end
local has_ansi_codes = runner.has_ansi_codes(jj_diff_colored)
runner.assert_test(
  "jj diff produces ANSI color codes",
  has_ansi_codes,
  "No ANSI escape sequences found"
)

if has_ansi_codes then
  runner.info("Found ANSI codes in diff output")
end

runner.section("Buffer Creation and Processing")
-- Test 3: Create diff buffer and verify ANSI codes are removed
if diff_module then
  local initial_buf_count = #vim.api.nvim_list_bufs()

  pcall(function()
    diff_module.show_file_diff(test_file)
  end)

  local final_buf_count = #vim.api.nvim_list_bufs()
  local diff_buffer_created = final_buf_count > initial_buf_count

  runner.assert_test(
    "Diff buffer created",
    diff_buffer_created,
    "No new buffer created by show_file_diff"
  )

  if diff_buffer_created then
    -- Find the diff buffer
    local diff_buffer = runner.find_buffer("jj%-diff.*" .. test_file)
    runner.assert_test(
      "Diff buffer found",
      diff_buffer ~= nil,
      "Could not find diff buffer by name"
    )

    if diff_buffer then
      local lines = vim.api.nvim_buf_get_lines(diff_buffer, 0, -1, false)
      local content = table.concat(lines, "\n")

      -- Test 4: Verify ANSI codes are stripped from buffer content
      local has_ansi_in_buffer = runner.has_ansi_codes(content)
      runner.assert_test(
        "ANSI codes stripped from buffer",
        not has_ansi_in_buffer,
        "ANSI codes still present in buffer text"
      )

      -- Test 5: Verify buffer has diff content
      local has_diff_content = content:match("diff --git")
        or content:match("@@")
        or content:match("Added regular file")
      runner.assert_test(
        "Buffer has diff content",
        has_diff_content,
        "No diff markers found in buffer"
      )

      -- Test 6: Check for highlight groups in buffer
      -- Get all highlights in the buffer - use namespace -1 to get all namespaces
      local highlights = {}
      local line_count = vim.api.nvim_buf_line_count(diff_buffer)

      for line = 0, math.min(line_count - 1, 10) do -- Check first 10 lines to avoid too much output
        local line_highlights = vim.api.nvim_buf_get_extmarks(
          diff_buffer,
          -1, -- all namespaces
          { line, 0 },
          { line, -1 },
          { details = true }
        )
        for _, hl in ipairs(line_highlights) do
          if hl[4] and hl[4].hl_group then
            table.insert(highlights, hl[4].hl_group)
          end
        end
      end

      local has_color_highlights = #highlights > 0
      runner.assert_test(
        "Buffer has color highlights",
        has_color_highlights,
        "No highlight groups found in buffer"
      )

      if has_color_highlights then
        runner.info("Found highlight groups: " .. table.concat(highlights, ", "))
      else
        runner.info("No highlight groups found - this might be expected in headless mode")
      end

      runner.info("Buffer content length: " .. string.len(content))
      runner.info("First 150 chars: " .. string.sub(content, 1, 150))
    end
  end
end

-- Cleanup
pcall(function()
  os.remove(test_file)
end)

runner.finish({
  "📝 Key achievements:",
  "   ✅ ANSI escape codes properly detected in jj diff output",
  "   ✅ Buffer creation and ANSI code stripping working correctly",
  "   ✅ Highlight groups applied to diff buffers",
  "   ✅ Color rendering pipeline functional",
})
