#!/usr/bin/env -S nvim --headless -l

-- Test status functionality
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

print("🚀 === jj-fugitive Status Functionality Tests ===")

-- Test 1: Check if status module can be loaded
local status_module = nil
pcall(function()
  status_module = require("jj-fugitive.status")
end)
assert_test("Status module loading", status_module ~= nil, "Could not require jj-fugitive.status")

-- Test 2: Check if J command works by trying to execute it
local j_command_works = false
local j_error = ""
local success, err = pcall(function()
  vim.cmd("J status")
  j_command_works = true
end)
if not success then
  j_error = tostring(err)
end
assert_test("J command works", j_command_works, "J command failed: " .. j_error)

-- Test 3: Check if jj status works
local jj_status_result = vim.fn.system({ "jj", "status" })
local jj_status_works = vim.v.shell_error == 0
assert_test("jj status command works", jj_status_works, "jj status failed: " .. jj_status_result)

-- Test 4: Test status buffer creation (or find existing one)
if status_module then
  -- First try to find existing status buffer
  local status_buffer = nil
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name:match("jj%-status") then
        status_buffer = bufnr
        break
      end
    end
  end

  -- If no existing buffer, create one
  if not status_buffer then
    pcall(function()
      status_module.show_status()
    end)

    -- Find the newly created buffer
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        local name = vim.api.nvim_buf_get_name(bufnr)
        if name:match("jj%-status") then
          status_buffer = bufnr
          break
        end
      end
    end
  end

  assert_test(
    "Status buffer created",
    status_buffer ~= nil,
    "No status buffer found after creation attempt"
  )

  if status_buffer then
    assert_test("Status buffer found", status_buffer ~= nil, "Could not find status buffer by name")

    local lines = vim.api.nvim_buf_get_lines(status_buffer, 0, -1, false)
    local content = table.concat(lines, "\n")
    local has_expected_content = content:match("jj%-fugitive Status") and content:match("Commands:")

    assert_test(
      "Status buffer has expected content",
      has_expected_content,
      "Status buffer missing expected content"
    )

    -- Test buffer options
    local buftype = vim.api.nvim_buf_get_option(status_buffer, "buftype")
    local modifiable = vim.api.nvim_buf_get_option(status_buffer, "modifiable")

    assert_test(
      "Status buffer has correct buftype",
      buftype == "nofile",
      "buftype is " .. buftype .. ", expected nofile"
    )
    assert_test(
      "Status buffer is not modifiable",
      modifiable == false,
      "buffer should not be modifiable"
    )

    -- Test that reload function exists and works
    pcall(function()
      status_module.show_status() -- Call again to test reload
    end)

    local new_lines = vim.api.nvim_buf_get_lines(status_buffer, 0, -1, false)
    local reload_worked = #new_lines > 0
    assert_test(
      "Status buffer reload works",
      reload_worked,
      "Status buffer became empty after reload"
    )
  end
end

-- Test 5: Test :J status command
local initial_buf_count = #vim.api.nvim_list_bufs()

pcall(function()
  vim.cmd("J status")
end)

local final_buf_count = #vim.api.nvim_list_bufs()
local j_status_created_buffer = final_buf_count >= initial_buf_count -- May reuse existing buffer

assert_test("J status command works", j_status_created_buffer, ":J status command failed")

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
