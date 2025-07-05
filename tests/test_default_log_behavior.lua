#!/usr/bin/env -S nvim --headless -l

-- Test default log behavior vs full repository log
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

print("🚀 === Default Log Behavior Tests ===")

-- Test 1: Module loading
local main_module = require("jj-fugitive.init")
assert_test("Main module loads", main_module ~= nil, "Could not load main module")

local log_module = require("jj-fugitive.log")
assert_test("Log module loads", log_module ~= nil, "Could not load log module")

-- Test 2: Default jj log behavior (no arguments)
print("\n🧪 Test 2: Default jj log behavior")
local default_log = main_module.run_jj_command_from_module({ "log", "--color", "always" })
assert_test("Default log command works", default_log ~= nil, "Default log command failed")

if default_log then
  local default_lines = vim.split(default_log, "\n")
  -- Remove empty lines for accurate count
  local non_empty_lines = 0
  for _, line in ipairs(default_lines) do
    if line:match("%S") then -- line contains non-whitespace
      non_empty_lines = non_empty_lines + 1
    end
  end

  assert_test(
    "Default log shows limited output",
    non_empty_lines <= 10,
    string.format("Expected ≤10 lines, got %d", non_empty_lines)
  )

  -- Check that it contains current working copy (@)
  local has_working_copy = false
  for _, line in ipairs(default_lines) do
    if line:match("@") then
      has_working_copy = true
      break
    end
  end
  assert_test(
    "Default log contains working copy (@)",
    has_working_copy,
    "No @ symbol found in default log"
  )
end

-- Test 3: Full repository log with -r ..
print("\n🧪 Test 3: Full repository log with -r ..")
local full_log = main_module.run_jj_command_from_module({ "log", "--color", "always", "-r", ".." })
assert_test("Full log command works", full_log ~= nil, "Full log command failed")

if full_log then
  local full_lines = vim.split(full_log, "\n")
  local non_empty_full_lines = 0
  for _, line in ipairs(full_lines) do
    if line:match("%S") then -- line contains non-whitespace
      non_empty_full_lines = non_empty_full_lines + 1
    end
  end

  assert_test(
    "Full log shows more output",
    non_empty_full_lines > 20,
    string.format("Expected >20 lines, got %d", non_empty_full_lines)
  )
end

-- Test 4: Compare default vs full log
print("\n🧪 Test 4: Compare default vs full log behavior")
if default_log and full_log then
  local default_lines = vim.split(default_log, "\n")
  local full_lines = vim.split(full_log, "\n")

  assert_test(
    "Default log is significantly shorter than full log",
    #default_lines < (#full_lines / 2),
    string.format("Default: %d lines, Full: %d lines", #default_lines, #full_lines)
  )
end

-- Test 5: Test log module's show_log function with no options
print("\n🧪 Test 5: Log module show_log with default options")
log_module.show_log()

-- Check if a log buffer was created
vim.defer_fn(function()
  local log_buffer_found = false
  local log_buffer_lines = 0

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name:match("jj%-log") or name == "" then
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        for _, line in ipairs(lines) do
          if line:match("jj Log View") then
            log_buffer_found = true
            log_buffer_lines = #lines
            break
          end
        end
        if log_buffer_found then
          break
        end
      end
    end
  end

  assert_test("Log buffer created successfully", log_buffer_found, "No log buffer found")
  assert_test(
    "Log buffer contains reasonable amount of content",
    log_buffer_lines > 5 and log_buffer_lines < 50,
    string.format("Expected 5-50 lines, got %d", log_buffer_lines)
  )

  -- Test 6: Test expand functionality preserves the ability to see full repo
  print("\n🧪 Test 6: Expand functionality available")
  if log_buffer_found then
    -- Check that buffer has expand keymaps
    local current_buf = vim.api.nvim_get_current_buf()
    local keymaps = vim.api.nvim_buf_get_keymap(current_buf, "n")
    local has_expand_keymap = false
    for _, keymap in ipairs(keymaps) do
      if keymap.lhs == "=" or keymap.lhs == "+" then
        has_expand_keymap = true
        break
      end
    end
    assert_test("Expand keymaps available", has_expand_keymap, "No expand keymaps (= or +) found")
  end

  -- Summary
  print("\n📊 === Default Log Behavior Test Results Summary ===")
  local passed = 0
  local total = #test_results

  for _, result in ipairs(test_results) do
    if result.passed then
      passed = passed + 1
    end
  end

  print(string.format("Passed: %d/%d tests", passed, total))

  if passed == total then
    print("🎉 All default log behavior tests passed!")
    print("")
    print("Key behaviors verified:")
    print("  ✅ Default :J log shows standard jj log output (recent commits)")
    print("  ✅ Full repository history available via expand functionality")
    print("  ✅ Default log is significantly shorter than full repo log")
    print("  ✅ Expand keymaps (= and +) available for showing more commits")
    print("  ✅ Log buffer creation works with new default behavior")
    os.exit(0)
  else
    print("💥 Some default log behavior tests failed!")
    for _, result in ipairs(test_results) do
      if not result.passed then
        print("  ❌ " .. result.name .. ": " .. (result.message or ""))
      end
    end
    os.exit(1)
  end
end, 100)

-- Keep running for the defer_fn
vim.loop.run("default")
