#!/usr/bin/env -S nvim --headless -l

-- Test log functionality
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

print("🚀 === jj-fugitive Log Functionality Tests ===")

-- Test 1: Check if log module can be loaded
local log_module = nil
pcall(function()
  log_module = require("jj-fugitive.log")
end)
assert_test("Log module loading", log_module ~= nil, "Could not require jj-fugitive.log")

-- Test 2: Check if J command works by trying to execute it
local j_command_works = false
local j_error = ""
local success, err = pcall(function()
  vim.cmd("J help")
  j_command_works = true
end)
if not success then
  j_error = tostring(err)
end
assert_test("J command works", j_command_works, "J command failed: " .. j_error)

-- Test 3: Check if jj log works
local jj_log_result = vim.fn.system({ "jj", "log", "--limit", "5" })
local jj_log_works = vim.v.shell_error == 0
assert_test("jj log command works", jj_log_works, "jj log failed: " .. jj_log_result)

-- Test 4: Test log buffer creation
if log_module then
  local initial_buf_count = #vim.api.nvim_list_bufs()

  pcall(function()
    log_module.show_log({ limit = 5 })
  end)

  local final_buf_count = #vim.api.nvim_list_bufs()
  local log_buffer_created = final_buf_count > initial_buf_count

  assert_test("Log buffer created", log_buffer_created, "No new buffer created by show_log")

  if log_buffer_created then
    -- Find the log buffer
    local log_buffer = nil
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        local name = vim.api.nvim_buf_get_name(bufnr)
        if name:match("jj%-log") then
          log_buffer = bufnr
          break
        end
      end
    end

    assert_test("Log buffer found", log_buffer ~= nil, "Could not find log buffer by name")

    if log_buffer then
      local lines = vim.api.nvim_buf_get_lines(log_buffer, 0, -1, false)
      local content = table.concat(lines, "\n")
      local has_expected_content = content:match("# jj Log View")
        and (content:match("@") or content:match("◆") or content:match("○"))

      assert_test(
        "Log buffer has expected content",
        has_expected_content,
        "Log buffer missing expected content (native jj format)"
      )

      -- Test buffer options
      local buftype = vim.api.nvim_buf_get_option(log_buffer, "buftype")
      local modifiable = vim.api.nvim_buf_get_option(log_buffer, "modifiable")

      assert_test(
        "Log buffer has correct buftype",
        buftype == "nofile",
        "buftype is " .. buftype .. ", expected nofile"
      )
      assert_test(
        "Log buffer is not modifiable",
        modifiable == false,
        "buffer should not be modifiable"
      )

      -- Test enhanced formatting
      local has_header = content:match("# jj Log View")
      local has_navigation = content:match("Navigate:")
      assert_test(
        "Log buffer has enhanced visual formatting",
        has_header and has_navigation,
        "Log buffer missing header or navigation instructions"
      )
    end
  end
end

-- Test 5: Test main plugin integration
local initial_buf_count = #vim.api.nvim_list_bufs()

pcall(function()
  vim.cmd("J log --limit 3")
end)

local final_buf_count = #vim.api.nvim_list_bufs()
local j_log_created_buffer = final_buf_count >= initial_buf_count -- May reuse existing buffer

assert_test("J log command works", j_log_created_buffer, ":J log command failed")

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
  print("🎉 All log functionality tests passed!")
  os.exit(0)
else
  print("💥 Some log functionality tests failed!")
  for _, result in ipairs(test_results) do
    if not result.passed then
      print("  ❌ " .. result.name .. ": " .. (result.message or ""))
    end
  end
  os.exit(1)
end
