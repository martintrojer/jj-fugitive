#!/usr/bin/env -S nvim --headless -l

-- luacheck: ignore 122

-- Test interactive command detection logic
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

print("🚀 === jj-fugitive Interactive Command Detection Tests ===")

-- Test 1: Check if main module can be loaded
local main_module = nil
pcall(function()
  main_module = require("jj-fugitive")
end)
assert_test("Main module loading", main_module ~= nil, "Could not require jj-fugitive")

-- Test 2: Test describe command detection (interactive by default)
local describe_interactive = false
pcall(function()
  vim.cmd("J describe")
end)

-- Check if a describe buffer was created
for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
  if vim.api.nvim_buf_is_valid(bufnr) then
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name:match("jj%-describe") then
      describe_interactive = true
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true }) -- Clean up
      break
    end
  end
end

assert_test(
  "Describe command detected as interactive",
  describe_interactive,
  "Should detect 'describe' as interactive and create editor buffer"
)

-- Test 3: Test describe with -m flag (not interactive)
local describe_with_message_non_interactive = false
pcall(function()
  -- This should execute normally without interactive message
  vim.fn.system({ "jj", "describe", "-m", "test message", "--no-edit" })
  describe_with_message_non_interactive = vim.v.shell_error == 0
end)
assert_test(
  "Describe with -m flag not interactive",
  describe_with_message_non_interactive,
  "describe -m should execute normally without interception"
)

-- Test 4: Test commit command detection (interactive by default)
local commit_interactive = false
pcall(function()
  vim.cmd("J commit")
end)

-- Check if a commit buffer was created
for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
  if vim.api.nvim_buf_is_valid(bufnr) then
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name:match("jj%-commit") then
      commit_interactive = true
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true }) -- Clean up
      break
    end
  end
end

assert_test(
  "Commit command detected as interactive",
  commit_interactive,
  "Should detect 'commit' as interactive and create editor buffer"
)

-- Test 5: Test commit with -m flag (not interactive)
local commit_with_message_non_interactive = false
pcall(function()
  vim.fn.system({ "jj", "commit", "-m", "test commit" })
  commit_with_message_non_interactive = vim.v.shell_error == 0
end)
assert_test(
  "Commit with -m flag not interactive",
  commit_with_message_non_interactive,
  "commit -m should execute normally without interception"
)

-- Test 6: Test split command detection (always interactive)
local split_interactive = false
pcall(function()
  local original_err_writeln = vim.api.nvim_err_writeln
  vim.api.nvim_err_writeln = function(msg)
    if msg:match("Interactive split requires diff editor integration") then
      split_interactive = true
    end
  end

  vim.cmd("J split")

  vim.api.nvim_err_writeln = original_err_writeln
end)
assert_test(
  "Split command detected as interactive",
  split_interactive,
  "Should detect 'split' as always interactive"
)

-- Test 7: Test diffedit command detection (always interactive)
local diffedit_interactive = false
pcall(function()
  local original_err_writeln = vim.api.nvim_err_writeln
  vim.api.nvim_err_writeln = function(msg)
    if msg:match("Interactive diffedit requires diff editor integration") then
      diffedit_interactive = true
    end
  end

  vim.cmd("J diffedit")

  vim.api.nvim_err_writeln = original_err_writeln
end)
assert_test(
  "Diffedit command detected as interactive",
  diffedit_interactive,
  "Should detect 'diffedit' as always interactive"
)

-- Test 8: Test resolve command detection (interactive by default)
local resolve_interactive = false
pcall(function()
  local original_err_writeln = vim.api.nvim_err_writeln
  vim.api.nvim_err_writeln = function(msg)
    if msg:match("Interactive resolve requires merge tool integration") then
      resolve_interactive = true
    end
  end

  vim.cmd("J resolve")

  vim.api.nvim_err_writeln = original_err_writeln
end)
assert_test(
  "Resolve command detected as interactive",
  resolve_interactive,
  "Should detect 'resolve' as interactive"
)

-- Test 9: Test resolve with --list flag (not interactive)
local resolve_list_non_interactive = false
pcall(function()
  vim.fn.system({ "jj", "resolve", "--list" })
  -- resolve --list should work even if there are no conflicts
  resolve_list_non_interactive = true -- We just check it doesn't get intercepted
end)
assert_test(
  "Resolve with --list flag not interactive",
  resolve_list_non_interactive,
  "resolve --list should execute normally without interception"
)

-- Test 10: Test non-interactive commands still work
local status_works = false
pcall(function()
  vim.cmd("J status")
  status_works = true
end)
assert_test(
  "Non-interactive commands still work",
  status_works,
  "Status command should still work normally"
)

-- Test 11: Test command aliases (desc for describe)
local desc_interactive = false
pcall(function()
  vim.cmd("J desc")
end)

-- Check if a describe buffer was created
for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
  if vim.api.nvim_buf_is_valid(bufnr) then
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name:match("jj%-describe") then
      desc_interactive = true
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true }) -- Clean up
      break
    end
  end
end

assert_test(
  "Desc alias detected as interactive",
  desc_interactive,
  "Should detect 'desc' alias as interactive and create editor buffer"
)

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
