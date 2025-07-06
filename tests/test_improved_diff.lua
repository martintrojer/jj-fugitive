#!/usr/bin/env -S nvim --headless -l

-- Test improved diff functionality with native jj colorization
local runner = require("tests.test_runner")

runner.init("jj-fugitive Improved Diff Tests")

-- Create a test file to ensure we have changes to test with
local test_file = "test_improved_diff.txt"
runner.create_test_file(test_file, "Original line 1\nOriginal line 2\nOriginal line 3\n")
vim.fn.system({ "jj", "file", "track", test_file })

-- Modify the file to create changes
local file = io.open(test_file, "w")
if file then
  file:write("Modified line 1\nOriginal line 2\nNew line 4\n")
  file:close()
end

-- Test 1: Load diff module
local diff_module = runner.load_module("jj-fugitive.diff")

-- Test 2: Test native jj diff commands with colors
local native_diff = vim.fn.system({ "jj", "diff", "--color", "always", test_file })
runner.assert_test(
  "Native jj diff with colors works",
  native_diff ~= nil and native_diff ~= "",
  "jj diff command should produce output"
)

runner.assert_test(
  "Native diff contains ANSI color codes",
  runner.has_ansi_codes(native_diff),
  "Native jj diff should contain ANSI escape sequences"
)

-- Test 3: Test different jj diff formats
local git_format = vim.fn.system({ "jj", "diff", "--color", "always", "--git", test_file })
runner.assert_test(
  "jj diff format 'git' works",
  git_format ~= nil and git_format ~= "",
  "Git format diff should work"
)

local color_words = vim.fn.system({ "jj", "diff", "--color", "always", "--color-words", test_file })
runner.assert_test(
  "jj diff format 'color-words' works",
  color_words ~= nil and color_words ~= "",
  "Color-words format diff should work"
)

local default_format = vim.fn.system({ "jj", "diff", "--color", "always", test_file })
runner.assert_test(
  "jj diff format 'default' works",
  default_format ~= nil and default_format ~= "",
  "Default format diff should work"
)

-- Test 4: Test diff buffer creation and properties
if diff_module then
  local success = pcall(function()
    diff_module.show_file_diff(test_file, { format = "git" })
  end)
  runner.assert_test(
    "Diff buffer creation with git format",
    success,
    "show_file_diff should work with git format"
  )
end

local diff_bufnr = runner.find_buffer("jj%-diff")
runner.assert_test("Diff buffer created", diff_bufnr ~= nil, "Diff buffer should be created")

if diff_bufnr then
  local filetype = vim.api.nvim_buf_get_option(diff_bufnr, "filetype")
  runner.assert_test(
    "Diff buffer has correct filetype",
    filetype == "diff",
    "Diff buffer should have 'diff' filetype"
  )

  local content = vim.api.nvim_buf_get_lines(diff_bufnr, 0, -1, false)
  local has_content = #content > 0 and table.concat(content, "\n") ~= ""
  runner.assert_test(
    "Diff buffer has content",
    has_content,
    "Diff buffer should contain diff content"
  )

  local content_str = table.concat(content, "\n")
  runner.assert_test(
    "Diff buffer contains proper diff content",
    content_str:match("diff") or content_str:match("@@"),
    "Buffer should contain diff markers"
  )

  -- Test keymaps
  local keymaps = vim.api.nvim_buf_get_keymap(diff_bufnr, "n")
  local has_f_key = false
  local has_r_key = false

  for _, keymap in ipairs(keymaps) do
    if keymap.lhs == "f" then
      has_f_key = true
    end
    if keymap.lhs == "r" then
      has_r_key = true
    end
  end

  runner.assert_test(
    "'f' key mapping exists for format selection",
    has_f_key,
    "Diff buffer should have 'f' key mapping"
  )

  runner.assert_test(
    "'r' key mapping exists for refresh",
    has_r_key,
    "Diff buffer should have 'r' key mapping"
  )

  -- Test buffer-local mappings
  local f_mapping = vim.fn.maparg("f", "n", false, true)
  runner.assert_test(
    "'f' mapping is buffer-local",
    f_mapping and f_mapping.buffer == 1,
    "Format selection mapping should be buffer-local"
  )
end

-- Test 5: Test format selector function
if diff_module then
  runner.assert_test(
    "Format selector function exists",
    type(diff_module.show_file_diff_format_selector) == "function",
    "show_file_diff_format_selector should be a function"
  )
end

-- Test 6: Test various diff options
local diff_context =
  vim.fn.system({ "jj", "diff", "--color", "always", "--context", "10", test_file })
runner.assert_test(
  "Diff with context option works",
  diff_context ~= nil and diff_context ~= "",
  "Context option should work"
)

local diff_color_words =
  vim.fn.system({ "jj", "diff", "--color", "always", "--color-words", test_file })
runner.assert_test(
  "Diff with color_words option works",
  diff_color_words ~= nil and diff_color_words ~= "",
  "Color-words option should work"
)

local diff_ignore_ws =
  vim.fn.system({ "jj", "diff", "--color", "always", "--ignore-all-space", test_file })
runner.assert_test(
  "Diff with ignore_whitespace option works",
  diff_ignore_ws ~= nil and diff_ignore_ws ~= "",
  "Ignore whitespace option should work"
)

-- Clean up test file
pcall(function()
  os.remove(test_file)
end)

local summary = {
  "✅ Native jj colorization and enhanced diff formats work correctly",
}

runner.finish(summary)
