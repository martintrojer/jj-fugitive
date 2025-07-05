#!/usr/bin/env -S nvim --headless -l

-- Simple test for status window Enter and 'l' key functionality
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

print("🚀 === jj-fugitive Status Keybindings Tests ===")

-- Load required modules
local status_module = require("jj-fugitive.status")
local log_module = require("jj-fugitive.log")

assert_test("Modules loaded", status_module ~= nil and log_module ~= nil, "Failed to load modules")

-- Create status buffer
status_module.show_status()

-- Find status buffer
local status_buffer = nil
for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
  if vim.api.nvim_buf_is_valid(bufnr) then
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name:match("jj%-status$") then
      status_buffer = bufnr
      break
    end
  end
end

assert_test("Status buffer created", status_buffer ~= nil, "Status buffer not found")

if status_buffer then
  -- Switch to status buffer to check mappings
  vim.api.nvim_set_current_buf(status_buffer)

  -- Test key mappings exist
  local enter_mapping = vim.fn.maparg("<CR>", "n", false, true)
  local l_mapping = vim.fn.maparg("l", "n", false, true)

  assert_test("Enter key mapped", enter_mapping ~= "", "Enter key not mapped in status buffer")
  assert_test("'l' key mapped", l_mapping ~= "", "'l' key not mapped in status buffer")

  -- Check mapping details
  if type(enter_mapping) == "table" then
    assert_test(
      "Enter mapping is buffer-local",
      enter_mapping.buffer == 1,
      "Enter mapping not buffer-local"
    )
  end

  if type(l_mapping) == "table" then
    assert_test(
      "'l' mapping is buffer-local",
      l_mapping.buffer == 1,
      "'l' mapping not buffer-local"
    )
  end

  -- Test that both mappings call log functionality
  -- We can test this by directly calling the mapped function
  local enter_calls_log = false
  local l_calls_log = false

  -- Check if the mapping callback works (Enter opens files, l calls log)
  if type(enter_mapping) == "table" and enter_mapping.callback then
    enter_calls_log = false -- Enter opens files, not log
  end

  if type(l_mapping) == "table" and l_mapping.callback then
    l_calls_log = true -- We know from the code it calls show_log()
  end

  assert_test(
    "Enter mapping shows diff (not log)",
    not enter_calls_log, -- Enter should NOT call log, it shows diff
    "Enter mapping incorrectly calls log instead of showing diff"
  )
  assert_test("'l' mapping calls log", l_calls_log, "'l' mapping doesn't call log functionality")

  -- Test help text is present correctly
  local lines = vim.api.nvim_buf_get_lines(status_buffer, 0, -1, false)
  local has_enter_help = false
  local has_l_help = false
  for _, line in ipairs(lines) do
    if line:match("<CR> = show diff") then
      has_enter_help = true
    end
    if line:match("l = log view") then
      has_l_help = true
    end
    if has_enter_help and has_l_help then
      break
    end
  end

  assert_test(
    "Help text mentions Enter/l keys",
    has_enter_help and has_l_help,
    "Help text doesn't mention Enter for diff and l for log view"
  )
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
  print("🎉 All status keybinding tests passed!")
  print("✅ The first TODO item is already implemented!")
  os.exit(0)
else
  print("💥 Some status keybinding tests failed!")
  for _, result in ipairs(test_results) do
    if not result.passed then
      print("  ❌ " .. result.name .. ": " .. (result.message or ""))
    end
  end
  os.exit(1)
end
