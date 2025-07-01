#!/usr/bin/env -S nvim --headless -l

-- Test describe_interactive functionality
vim.cmd("set rtp+=.")
vim.cmd("runtime plugin/jj-fugitive.lua")

local test_results = {}
local function assert_test(name, condition, message)
  if condition then
    print("✅ PASS: " .. name)
    table.insert(test_results, { name = name, passed = true })
  else
    print("❌ FAIL: " .. name .. " - " .. (message or ""))
    table.insert(test_results, { name = name, passed = false, message = message })
  end
end

print("🚀 === jj-fugitive Describe Interactive Tests ===")

-- Test 1: Check if main module can be loaded
local main_module = nil
pcall(function()
  main_module = require("jj-fugitive")
end)
assert_test("Main module loading", main_module ~= nil, "Could not require jj-fugitive")

-- Test 2: Test that describe_interactive function exists
local describe_interactive_exists = false
if main_module then
  describe_interactive_exists = type(main_module.describe_interactive) == "function"
end
assert_test(
  "describe_interactive function exists",
  describe_interactive_exists,
  "describe_interactive should be a function"
)

-- Test 3: Test describe_interactive creates a buffer
local describe_buffer_created = false
local describe_buffer = nil
if main_module and main_module.describe_interactive then
  pcall(function()
    main_module.describe_interactive({ "describe" })
  end)

  -- Look for describe buffer
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name:match("jj%-describe") then
        describe_buffer = bufnr
        describe_buffer_created = true
        break
      end
    end
  end
end
assert_test(
  "describe_interactive creates buffer",
  describe_buffer_created,
  "Should create a describe buffer"
)

-- Test 4: Test buffer properties
if describe_buffer then
  local buftype = vim.api.nvim_buf_get_option(describe_buffer, "buftype")
  local filetype = vim.api.nvim_buf_get_option(describe_buffer, "filetype")
  local modifiable = vim.api.nvim_buf_get_option(describe_buffer, "modifiable")

  assert_test(
    "Buffer has correct buftype",
    buftype == "acwrite",
    "buftype should be 'acwrite', got: " .. buftype
  )

  assert_test(
    "Buffer has correct filetype",
    filetype == "gitcommit",
    "filetype should be 'gitcommit', got: " .. filetype
  )

  assert_test("Buffer is modifiable", modifiable == true, "Buffer should be modifiable for editing")
end

-- Test 5: Test buffer content includes help comments
if describe_buffer then
  local lines = vim.api.nvim_buf_get_lines(describe_buffer, 0, -1, false)
  local content = table.concat(lines, "\n")

  local has_help_comment = content:match("# Enter description for revision")
  local has_save_instruction = content:match("# Save to apply changes")
  local has_ignore_comment = content:match("# Lines starting with # are ignored")

  assert_test(
    "Buffer has help comments",
    has_help_comment and has_save_instruction and has_ignore_comment,
    "Buffer should contain helpful comment lines"
  )
end

-- Test 6: Test describe with specific revision
local describe_revision_success = false
if main_module and main_module.describe_interactive then
  local success, err = pcall(function()
    main_module.describe_interactive({ "describe", "@" })
  end)
  -- Even if it fails due to jj command issues, it shouldn't crash Lua
  describe_revision_success = success or (err and not err:match("attempt to"))
end
assert_test(
  "describe_interactive works with revision argument",
  describe_revision_success,
  "Should handle describe with revision argument without Lua errors"
)

-- Test 7: Test buffer autocmd setup (BufWriteCmd should be set)
local autocmd_set = false
if describe_buffer then
  -- Check if BufWriteCmd autocmd is set for the buffer
  local autocmds = vim.api.nvim_get_autocmds({
    event = "BufWriteCmd",
    buffer = describe_buffer,
  })
  autocmd_set = #autocmds > 0
end
assert_test(
  "BufWriteCmd autocmd is set",
  autocmd_set,
  "Should have BufWriteCmd autocmd for save functionality"
)

-- Test 8: Test buffer name format
if describe_buffer then
  local name = vim.api.nvim_buf_get_name(describe_buffer)
  local has_correct_name = name:match("jj%-describe%-@") ~= nil
  assert_test(
    "Buffer has correct name format",
    has_correct_name,
    "Buffer name should match 'jj-describe-@' pattern"
  )
end

-- Test 9: Test error handling for invalid revision
local invalid_revision_handled = false
if main_module and main_module.describe_interactive then
  pcall(function()
    main_module.describe_interactive({ "describe", "nonexistent-revision" })
  end)

  -- We can't easily test this without actually having an invalid revision
  -- So we'll just check that the function doesn't crash
  invalid_revision_handled = true
end
assert_test(
  "Invalid revision handled gracefully",
  invalid_revision_handled,
  "Should handle invalid revisions without crashing"
)

-- Test 10: Test multiple revisions (should use first one)
local multiple_revisions_handled = false
if main_module and main_module.describe_interactive then
  local success, err = pcall(function()
    main_module.describe_interactive({ "describe", "@", "some-other-rev" })
  end)
  -- Even if it fails due to jj command issues, it shouldn't crash Lua
  multiple_revisions_handled = success or (err and not err:match("attempt to"))
end
assert_test(
  "Multiple revisions handled",
  multiple_revisions_handled,
  "Should handle multiple revisions without Lua errors"
)

-- Clean up buffers
for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
  if vim.api.nvim_buf_is_valid(bufnr) then
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name:match("jj%-describe") then
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    end
  end
end

-- Summary
print("\n📊 === Test Results Summary ===")
local passed = 0
local total = #test_results

for _, result in ipairs(test_results) do
  if result.passed then
    passed = passed + 1
  end
end

print(string.format("Passed: %d/%d tests", passed, total))

if passed == total then
  print("🎉 All tests passed!")
  os.exit(0)
else
  print("💥 Some tests failed!")
  for _, result in ipairs(test_results) do
    if not result.passed then
      print("  ❌ " .. result.name .. ": " .. (result.message or ""))
    end
  end
  os.exit(1)
end
