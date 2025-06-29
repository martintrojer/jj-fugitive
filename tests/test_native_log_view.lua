#!/usr/bin/env -S nvim --headless -l

-- Test native-style log view functionality
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

print("🎨 === jj-fugitive Native Log View Tests ===")

local log_module = require("jj-fugitive.log")

-- Test 1: Check if log module loads
assert_test("Log module loading", log_module ~= nil, "Could not require jj-fugitive.log")

-- Test 2: Test raw jj log output with colors
local result = vim.fn.system({ "jj", "log", "--color", "always", "--limit", "3" })
assert_test(
  "Raw jj log produces colored output",
  result:match("\27%["),
  "jj log doesn't produce ANSI color codes"
)

-- Test 3: Create the log view
local initial_buf_count = #vim.api.nvim_list_bufs()
pcall(function()
  log_module.show_log({ limit = 5 })
end)

local after_buf_count = #vim.api.nvim_list_bufs()
local log_buf_created = after_buf_count > initial_buf_count

assert_test("Log view creates buffer", log_buf_created, "Log view didn't create a buffer")

-- Test 4: Verify buffer content
local log_buffer = nil
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  if vim.api.nvim_buf_is_valid(buf) then
    local name = vim.api.nvim_buf_get_name(buf)
    if name:match("jj%-log") then
      log_buffer = buf
      break
    end
  end
end

if log_buffer then
  local lines = vim.api.nvim_buf_get_lines(log_buffer, 0, -1, false)
  local content = table.concat(lines, "\n")

  assert_test(
    "Log buffer contains header",
    content:match("# jj Log View"),
    "Log buffer missing header"
  )

  assert_test(
    "Log buffer has no ANSI codes",
    not content:match("\27%["),
    "ANSI codes found in log buffer content"
  )

  assert_test(
    "Log buffer contains commit symbols",
    content:match("@") or content:match("◆") or content:match("○"),
    "Log buffer missing jj commit symbols"
  )

  local filetype = vim.api.nvim_buf_get_option(log_buffer, "filetype")
  assert_test(
    "Log buffer has diff filetype",
    filetype == "diff",
    "Log buffer filetype is " .. filetype .. ", expected diff"
  )
else
  assert_test("Log buffer found", false, "Could not find log buffer")
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
  print("🎉 All native log view tests passed!")
  print("📝 Key achievements:")
  print("   ✅ Native jj log format preserved")
  print("   ✅ ANSI colors properly processed")
  print("   ✅ Interactive buffer created successfully")
  print("   ✅ jj symbols and layout maintained")
  os.exit(0)
else
  print("💥 Some native log view tests failed!")
  for _, result in ipairs(test_results) do
    if not result.passed then
      print("  ❌ " .. result.name .. ": " .. (result.message or ""))
    end
  end
  os.exit(1)
end
