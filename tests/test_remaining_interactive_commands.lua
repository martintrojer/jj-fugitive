#!/usr/bin/env -S nvim --headless -l

-- luacheck: ignore 122

-- Test remaining interactive command functionality (split, diffedit, resolve)
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

print("🚀 === jj-fugitive Remaining Interactive Commands Tests ===")

-- Test 1: Check if main module can be loaded
local main_module = nil
pcall(function()
  main_module = require("jj-fugitive")
end)
assert_test("Main module loading", main_module ~= nil, "Could not require jj-fugitive")

-- Test 2: Test that split_interactive function exists
local split_interactive_exists = false
if main_module then
  split_interactive_exists = type(main_module.split_interactive) == "function"
end
assert_test(
  "split_interactive function exists",
  split_interactive_exists,
  "split_interactive should be a function"
)

-- Test 3: Test that diffedit_interactive function exists
local diffedit_interactive_exists = false
if main_module then
  diffedit_interactive_exists = type(main_module.diffedit_interactive) == "function"
end
assert_test(
  "diffedit_interactive function exists",
  diffedit_interactive_exists,
  "diffedit_interactive should be a function"
)

-- Test 4: Test that resolve_interactive function exists
local resolve_interactive_exists = false
if main_module then
  resolve_interactive_exists = type(main_module.resolve_interactive) == "function"
end
assert_test(
  "resolve_interactive function exists",
  resolve_interactive_exists,
  "resolve_interactive should be a function"
)

-- Test 5: Test split_interactive shows helpful error message
local split_error_message = false
local split_echo_message = false
if main_module and main_module.split_interactive then
  -- Capture error message
  local original_err_writeln = vim.api.nvim_err_writeln
  local original_echo = vim.api.nvim_echo

  vim.api.nvim_err_writeln = function(msg)
    if msg:match("Interactive split requires diff editor integration") then
      split_error_message = true
    end
  end

  vim.api.nvim_echo = function(chunks, _, _)
    for _, chunk in ipairs(chunks) do
      if chunk[1]:match("jj split %-i") then
        split_echo_message = true
        break
      end
    end
  end

  pcall(function()
    main_module.split_interactive({ "split" })
  end)

  -- Restore original functions
  vim.api.nvim_err_writeln = original_err_writeln
  vim.api.nvim_echo = original_echo
end
assert_test(
  "split_interactive shows error message",
  split_error_message,
  "Should show helpful error message about diff editor integration"
)
assert_test(
  "split_interactive shows alternative",
  split_echo_message,
  "Should show alternative terminal command"
)

-- Test 6: Test diffedit_interactive shows helpful error message
local diffedit_error_message = false
local diffedit_echo_message = false
if main_module and main_module.diffedit_interactive then
  local original_err_writeln = vim.api.nvim_err_writeln
  local original_echo = vim.api.nvim_echo

  vim.api.nvim_err_writeln = function(msg)
    if msg:match("Interactive diffedit requires diff editor integration") then
      diffedit_error_message = true
    end
  end

  vim.api.nvim_echo = function(chunks, _, _)
    for _, chunk in ipairs(chunks) do
      if chunk[1]:match("jj diffedit") then
        diffedit_echo_message = true
        break
      end
    end
  end

  pcall(function()
    main_module.diffedit_interactive({ "diffedit" })
  end)

  vim.api.nvim_err_writeln = original_err_writeln
  vim.api.nvim_echo = original_echo
end
assert_test(
  "diffedit_interactive shows error message",
  diffedit_error_message,
  "Should show helpful error message about diff editor integration"
)
assert_test(
  "diffedit_interactive shows alternative",
  diffedit_echo_message,
  "Should show alternative terminal command"
)

-- Test 7: Test resolve_interactive shows helpful error message
local resolve_error_message = false
local resolve_echo_message = false
if main_module and main_module.resolve_interactive then
  local original_err_writeln = vim.api.nvim_err_writeln
  local original_echo = vim.api.nvim_echo

  vim.api.nvim_err_writeln = function(msg)
    if msg:match("Interactive resolve requires merge tool integration") then
      resolve_error_message = true
    end
  end

  vim.api.nvim_echo = function(chunks, _, _)
    for _, chunk in ipairs(chunks) do
      if chunk[1]:match("jj resolve") then
        resolve_echo_message = true
        break
      end
    end
  end

  pcall(function()
    main_module.resolve_interactive({ "resolve" })
  end)

  vim.api.nvim_err_writeln = original_err_writeln
  vim.api.nvim_echo = original_echo
end
assert_test(
  "resolve_interactive shows error message",
  resolve_error_message,
  "Should show helpful error message about merge tool integration"
)
assert_test(
  "resolve_interactive shows alternative",
  resolve_echo_message,
  "Should show alternative terminal command"
)

-- Test 8: Test split_interactive doesn't crash with arguments
local split_with_args_handled = false
if main_module and main_module.split_interactive then
  pcall(function()
    main_module.split_interactive({ "split", "-r", "@" })
    split_with_args_handled = true
  end)
end
assert_test(
  "split_interactive handles arguments",
  split_with_args_handled,
  "Should handle split command with arguments without crashing"
)

-- Test 9: Test diffedit_interactive doesn't crash with arguments
local diffedit_with_args_handled = false
if main_module and main_module.diffedit_interactive then
  pcall(function()
    main_module.diffedit_interactive({ "diffedit", "-r", "@" })
    diffedit_with_args_handled = true
  end)
end
assert_test(
  "diffedit_interactive handles arguments",
  diffedit_with_args_handled,
  "Should handle diffedit command with arguments without crashing"
)

-- Test 10: Test resolve_interactive doesn't crash with arguments
local resolve_with_args_handled = false
if main_module and main_module.resolve_interactive then
  pcall(function()
    main_module.resolve_interactive({ "resolve", "file.txt" })
    resolve_with_args_handled = true
  end)
end
assert_test(
  "resolve_interactive handles arguments",
  resolve_with_args_handled,
  "Should handle resolve command with arguments without crashing"
)

-- Test 11: Test that functions don't create any buffers
local initial_buf_count = #vim.api.nvim_list_bufs()

if main_module then
  pcall(function()
    main_module.split_interactive({ "split" })
    main_module.diffedit_interactive({ "diffedit" })
    main_module.resolve_interactive({ "resolve" })
  end)
end

local final_buf_count = #vim.api.nvim_list_bufs()
local no_buffers_created = final_buf_count == initial_buf_count

assert_test(
  "No buffers created by error functions",
  no_buffers_created,
  "Error message functions should not create any buffers"
)

-- Test 12: Test error message format consistency
local consistent_error_format = true
if main_module then
  -- All error messages should mention "not yet implemented" or similar
  local split_has_consistent_format = false
  local diffedit_has_consistent_format = false
  local resolve_has_consistent_format = false

  local original_err_writeln = vim.api.nvim_err_writeln
  vim.api.nvim_err_writeln = function(msg)
    if msg:match("split") and msg:match("not yet implemented") then
      split_has_consistent_format = true
    end
    if msg:match("diffedit") and msg:match("not yet implemented") then
      diffedit_has_consistent_format = true
    end
    if msg:match("resolve") and msg:match("not yet implemented") then
      resolve_has_consistent_format = true
    end
  end

  pcall(function()
    main_module.split_interactive({ "split" })
    main_module.diffedit_interactive({ "diffedit" })
    main_module.resolve_interactive({ "resolve" })
  end)

  vim.api.nvim_err_writeln = original_err_writeln

  consistent_error_format = split_has_consistent_format
    and diffedit_has_consistent_format
    and resolve_has_consistent_format
end
assert_test(
  "Error message format is consistent",
  consistent_error_format,
  "All error messages should follow consistent format"
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
