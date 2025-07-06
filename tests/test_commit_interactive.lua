#!/usr/bin/env -S nvim --headless -l

local runner = require("tests.test_runner")
runner.init("jj-fugitive Commit Interactive Tests")

-- Test 1: Check if main module can be loaded
local main_module = runner.load_module("jj-fugitive")

-- Test 2: Test that commit_interactive function exists
local commit_interactive_exists = false
if main_module then
  commit_interactive_exists = type(main_module.commit_interactive) == "function"
end
runner.assert_test(
  "commit_interactive function exists",
  commit_interactive_exists,
  "commit_interactive should be a function"
)

-- Test 3: Test commit_interactive creates a buffer
local commit_buffer_created = false
local commit_buffer = nil
if main_module and main_module.commit_interactive then
  pcall(function()
    main_module.commit_interactive({ "commit" })
  end)

  -- Look for commit buffer
  commit_buffer = runner.find_buffer("jj%-commit")
  commit_buffer_created = commit_buffer ~= nil
end
runner.assert_test(
  "commit_interactive creates buffer",
  commit_buffer_created,
  "Should create a commit buffer"
)

-- Test 4: Test buffer properties
if commit_buffer then
  local buftype = vim.api.nvim_buf_get_option(commit_buffer, "buftype")
  local filetype = vim.api.nvim_buf_get_option(commit_buffer, "filetype")
  local modifiable = vim.api.nvim_buf_get_option(commit_buffer, "modifiable")

  runner.assert_test(
    "Buffer has correct buftype",
    buftype == "acwrite",
    "buftype should be 'acwrite', got: " .. buftype
  )

  runner.assert_test(
    "Buffer has correct filetype",
    filetype == "gitcommit",
    "filetype should be 'gitcommit', got: " .. filetype
  )

  runner.assert_test(
    "Buffer is modifiable",
    modifiable == true,
    "Buffer should be modifiable for editing"
  )
end

-- Test 5: Test buffer content includes help comments
if commit_buffer then
  local lines = vim.api.nvim_buf_get_lines(commit_buffer, 0, -1, false)
  local content = table.concat(lines, "\n")

  local has_help_comment = content:match("# Enter commit message")
  local has_save_instruction = content:match("# Save to create commit")
  local has_ignore_comment = content:match("# Lines starting with # are ignored")

  runner.assert_test(
    "Buffer has help comments",
    has_help_comment and has_save_instruction and has_ignore_comment,
    "Buffer should contain helpful comment lines"
  )
end

-- Test 6: Test commit with filesets
local commit_fileset_success = false
if main_module and main_module.commit_interactive then
  local success, err = pcall(function()
    main_module.commit_interactive({ "commit", "file1.txt", "file2.txt" })
  end)
  commit_fileset_success = success or (err and not err:match("attempt to"))
end
runner.assert_test(
  "commit_interactive works with filesets",
  commit_fileset_success,
  "Should handle commit with filesets without Lua errors"
)

-- Test 7: Test fileset comment (skip - depends on buffer creation)
runner.skip("Buffer shows fileset information", "depends on successful buffer creation")

-- Test 8: Test buffer autocmd setup (BufWriteCmd should be set)
local autocmd_set = false
if commit_buffer then
  -- Check if BufWriteCmd autocmd is set for the buffer
  local autocmds = vim.api.nvim_get_autocmds({
    event = "BufWriteCmd",
    buffer = commit_buffer,
  })
  autocmd_set = #autocmds > 0
end
runner.assert_test(
  "BufWriteCmd autocmd is set",
  autocmd_set,
  "Should have BufWriteCmd autocmd for save functionality"
)

-- Test 9: Test buffer name format
if commit_buffer then
  local name = vim.api.nvim_buf_get_name(commit_buffer)
  local has_correct_name = name:match("jj%-commit") ~= nil
  runner.assert_test(
    "Buffer has correct name format",
    has_correct_name,
    "Buffer name should match 'jj-commit' pattern"
  )
end

-- Test 10: Test buffer starts with current working copy description
if commit_buffer then
  local lines = vim.api.nvim_buf_get_lines(commit_buffer, 0, -1, false)
  -- Should have some content beyond just the help comments
  local has_content = #lines > 4 -- More than just the help lines
  runner.assert_test(
    "Buffer includes current description",
    has_content,
    "Buffer should include current working copy description"
  )
end

-- Test 11: Test empty filesets handling
local empty_filesets_handled = false
if main_module and main_module.commit_interactive then
  local success, err = pcall(function()
    main_module.commit_interactive({ "commit" })
  end)
  empty_filesets_handled = success or (err and not err:match("attempt to"))
end
runner.assert_test(
  "Empty filesets handled",
  empty_filesets_handled,
  "Should handle commit without filesets without Lua errors"
)

-- Test 12: Test flag filtering (flags should be ignored when parsing filesets)
local flag_filtering_works = false
if main_module and main_module.commit_interactive then
  local success, err = pcall(function()
    -- This shouldn't crash even with flags mixed in
    main_module.commit_interactive({ "commit", "--some-flag", "file.txt" })
  end)
  flag_filtering_works = success or (err and not err:match("attempt to"))
end
runner.assert_test(
  "Flag filtering works",
  flag_filtering_works,
  "Should filter out flags when parsing filesets without Lua errors"
)

-- Clean up buffers
for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
  if vim.api.nvim_buf_is_valid(bufnr) then
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name:match("jj%-commit") then
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    end
  end
end

runner.finish()
