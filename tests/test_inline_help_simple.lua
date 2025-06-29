#!/usr/bin/env -S nvim --headless -l

-- Test inline help functionality - simple version
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

print("🚀 === jj-fugitive Inline Help Simple Tests ===")

-- Test 1: Load completion module with new help functions
local completion_module = require("jj-fugitive.completion")
assert_test(
  "Completion module loaded",
  completion_module ~= nil,
  "Could not load completion module"
)

-- Test 2: Check new help functions exist
if completion_module then
  assert_test(
    "get_command_help function exists",
    type(completion_module.get_command_help) == "function",
    "get_command_help function not found"
  )

  assert_test(
    "get_flag_help function exists",
    type(completion_module.get_flag_help) == "function",
    "get_flag_help function not found"
  )

  assert_test(
    "show_inline_help function exists",
    type(completion_module.show_inline_help) == "function",
    "show_inline_help function not found"
  )
end

-- Test 3: Test enhanced parsing doesn't break existing functionality
if completion_module then
  -- Clear cache to ensure fresh parsing
  completion_module.clear_cache()

  local completions = completion_module.complete("st", "J st", 4)
  assert_test(
    "Basic completion still works",
    type(completions) == "table" and #completions > 0,
    "Basic completion should work with enhanced parsing"
  )

  local has_status = vim.tbl_contains(completions, "status")
  assert_test("Status command in completions", has_status, "Status command should be available")

  -- Test flag completion
  local flag_completions = completion_module.complete("--", "J status --", 10)
  assert_test(
    "Flag completion works",
    type(flag_completions) == "table",
    "Flag completion should return table"
  )

  local has_help_flag = vim.tbl_contains(flag_completions, "--help")
  assert_test("--help flag in completions", has_help_flag, "--help flag should be available")
end

-- Test 4: Test help extraction
if completion_module then
  local status_help = completion_module.get_command_help("status")
  assert_test(
    "Command help extraction returns string",
    type(status_help) == "string",
    "get_command_help should return a string"
  )

  local help_flag_desc = completion_module.get_flag_help("status", "--help")
  assert_test(
    "Flag help extraction returns string",
    type(help_flag_desc) == "string",
    "get_flag_help should return a string"
  )

  -- The --help flag should have some description now
  print("  📝 --help flag description: '" .. help_flag_desc .. "'")
  assert_test(
    "--help flag has description",
    help_flag_desc ~= "",
    "--help flag should have a description"
  )
end

-- Test 5: Test inline help display (just that it doesn't crash)
if completion_module then
  local success1 = pcall(function()
    -- Test command help
    local help_win = completion_module.show_inline_help("J ")
    if help_win and vim.api.nvim_win_is_valid(help_win) then
      vim.api.nvim_win_close(help_win, true)
    end
  end)

  assert_test(
    "Command help display doesn't crash",
    success1,
    "show_inline_help should work for commands"
  )

  local success2 = pcall(function()
    -- Test flag help
    local help_win = completion_module.show_inline_help("J status ")
    if help_win and vim.api.nvim_win_is_valid(help_win) then
      vim.api.nvim_win_close(help_win, true)
    end
  end)

  assert_test("Flag help display doesn't crash", success2, "show_inline_help should work for flags")
end

-- Test 6: Test manual command execution (since the plugin might not auto-create commands in headless mode)
local main_module = require("jj-fugitive")
if main_module then
  assert_test(
    "Main module has complete function",
    type(main_module.complete) == "function",
    "Main module should have complete function"
  )

  local main_completions = main_module.complete("st", "J st", 4)
  assert_test(
    "Main module completion works",
    type(main_completions) == "table",
    "Main module completion should work"
  )
end

-- Summary
print("\n📊 === Simple Inline Help Test Results Summary ===")
local passed = 0
local total = #test_results

for _, result in ipairs(test_results) do
  if result.passed then
    passed = passed + 1
  end
end

print(string.format("Passed: %d/%d tests", passed, total))

if passed == total then
  print("🎉 All simple inline help tests passed!")
  print("✅ Enhanced completion with help extraction works correctly")
  print("")
  print("Features added:")
  print("  • Commands and flags now include descriptions from --help output")
  print("  • Inline help display function available")
  print("  • Backward compatibility maintained")
  os.exit(0)
else
  print("💥 Some simple inline help tests failed!")
  for _, result in ipairs(test_results) do
    if not result.passed then
      print("  ❌ " .. result.name .. ": " .. (result.message or ""))
    end
  end
  os.exit(1)
end
