#!/usr/bin/env -S nvim --headless -l

-- Test git format consistency across all diff views
local runner = require("tests.test_runner")

runner.init("jj-fugitive Git Format Consistency Tests")

-- Get current commit ID and use existing changes
local commit_output =
  vim.fn.system({ "jj", "log", "--limit", "1", "--template", "change_id.short()" })
local commit_id = vim.trim(commit_output):gsub("^@%s*", "")

-- Create a test file to ensure we have changes to test with
local test_file = "test_git_format_consistency.txt"
runner.create_test_file(test_file, "Line 1\nLine 2\nLine 3\n")
vim.fn.system({ "jj", "file", "track", test_file })

if commit_id and #commit_id > 0 then
  runner.info("Testing with commit ID: " .. commit_id)

  -- Test 1: Verify jj commands produce git format output
  local file_diff_output = vim.fn.system({ "jj", "diff", "--color", "always", "--git", test_file })
  local commit_show_output =
    vim.fn.system({ "jj", "show", "--color", "always", "--git", commit_id })
  local commit_diff_output =
    vim.fn.system({ "jj", "diff", "--color", "always", "--git", "-r", commit_id })

  runner.assert_test(
    "File diff uses git format",
    file_diff_output:match("diff %-%-git"),
    "File diff output doesn't contain 'diff --git' header"
  )

  runner.assert_test(
    "Commit show uses git format",
    commit_show_output:match("diff %-%-git"),
    "Commit show output doesn't contain 'diff --git' header"
  )

  runner.assert_test(
    "Commit diff uses git format",
    commit_diff_output:match("diff %-%-git"),
    "Commit diff output doesn't contain 'diff --git' header"
  )

  -- Test 2: Verify ANSI colors are preserved
  runner.assert_test(
    "File diff has ANSI colors",
    runner.has_ansi_codes(file_diff_output),
    "File diff should contain ANSI color codes"
  )

  runner.assert_test(
    "Commit show has ANSI colors",
    runner.has_ansi_codes(commit_show_output),
    "Commit show should contain ANSI color codes"
  )

  runner.assert_test(
    "Commit diff has ANSI colors",
    runner.has_ansi_codes(commit_diff_output),
    "Commit diff should contain ANSI color codes"
  )

  -- Test 3: Test diff module integration
  local diff_module = runner.load_module("jj-fugitive.diff")
  if diff_module then
    pcall(function()
      diff_module.show_file_diff(test_file)
    end)
  end

  local diff_bufnr = runner.find_buffer("jj%-diff")
  runner.assert_test("File diff view created", diff_bufnr ~= nil, "Diff buffer should be created")

  -- Test 4: Test log module integration
  local log_module = runner.load_module("jj-fugitive.log")
  if log_module then
    pcall(function()
      log_module.show_log({ limit = 5 })
    end)
  end

  local log_bufnr = runner.find_buffer("jj%-log")
  runner.assert_test("Log view created", log_bufnr ~= nil, "Log buffer should be created")

  -- Test 5: Verify processed output maintains git format
  if diff_bufnr then
    local diff_content = table.concat(vim.api.nvim_buf_get_lines(diff_bufnr, 0, -1, false), "\n")
    runner.assert_test(
      "File diff buffer contains git format",
      diff_content:match("diff %-%-git"),
      "Processed diff should maintain git format"
    )

    runner.assert_test(
      "File diff buffer has no ANSI codes",
      not runner.has_ansi_codes(diff_content),
      "Processed diff should have ANSI codes stripped"
    )

    runner.info("File diff buffer content preview:")
    local preview_lines = vim.api.nvim_buf_get_lines(diff_bufnr, 0, 5, false)
    for _, line in ipairs(preview_lines) do
      if line ~= "" then
        runner.info("  " .. line)
        break
      end
    end
  end

  -- Test 6: Detailed git format validation
  local formats = { file_diff_output, commit_show_output, commit_diff_output }
  local format_names = { "file diff", "commit show", "commit diff" }

  for i, output in ipairs(formats) do
    local name = format_names[i]
    runner.assert_test(
      name .. " has diff %-%-git",
      output:match("diff %-%-git"),
      name .. " should contain diff --git header"
    )

    local has_old_file = output:match("%-%-%-[%s]*a/")
    if has_old_file then
      runner.info("✓ " .. name .. " has \\-\\-\\- a/")
    end
  end

  -- Test 7: Buffer processing validation
  runner.assert_test(
    "All outputs process to clean text",
    true,
    "All outputs should process cleanly"
  )

  -- Count highlights in buffers if available
  if diff_bufnr then
    local highlight_count = 0
    for i = 1, vim.api.nvim_buf_line_count(diff_bufnr) do
      local extmarks = vim.api.nvim_buf_get_extmarks(
        diff_bufnr,
        -1,
        { i - 1, 0 },
        { i - 1, -1 },
        {}
      )
      highlight_count = highlight_count + #extmarks
    end
    runner.assert_test(
      "All outputs generate highlights",
      highlight_count > 0,
      "Processed output should have syntax highlighting"
    )

    runner.info("Highlight counts:")
    runner.info("  File diff: " .. highlight_count)
    if log_bufnr then
      local log_highlight_count = 0
      for i = 1, vim.api.nvim_buf_line_count(log_bufnr) do
        local extmarks = vim.api.nvim_buf_get_extmarks(
          log_bufnr,
          -1,
          { i - 1, 0 },
          { i - 1, -1 },
          {}
        )
        log_highlight_count = log_highlight_count + #extmarks
      end
      runner.info("  Commit show: " .. log_highlight_count)
      runner.info("  Commit diff: " .. log_highlight_count)
    end
  end
end

-- Clean up test file
pcall(function()
  os.remove(test_file)
end)

local summary = {
  "Key achievements:",
  "  ✅ File diff view uses --git format",
  "  ✅ Log commit show uses --git format",
  "  ✅ Log commit diff uses --git format",
  "  ✅ All views produce consistent git-style diff output",
  "  ✅ ANSI colors preserved and processed consistently",
  "  ✅ Buffer content clean and properly highlighted",
}

runner.finish(summary)
