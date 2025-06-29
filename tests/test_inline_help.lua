#!/usr/bin/env -S nvim --headless -l

-- Test inline help functionality
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

print("🚀 === jj-fugitive Inline Help Tests ===")

-- Test 1: Load completion module with new help functions
local completion_module = require("jj-fugitive.completion")
assert_test(
  "Completion module loaded",
  completion_module ~= nil,
  "Could not load completion module"
)

-- Test 2: Check new help functions exist
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

-- Test 3: Test command help extraction
if completion_module then
  local status_help = completion_module.get_command_help("status")
  assert_test(
    "Command help extraction works",
    type(status_help) == "string",
    "get_command_help should return a string"
  )

  -- Test with a command that should have help
  local log_help = completion_module.get_command_help("log")
  assert_test(
    "Log command help extracted",
    type(log_help) == "string",
    "get_command_help should return help for log command"
  )
end

-- Test 4: Test flag help extraction
if completion_module then
  local help_flag_help = completion_module.get_flag_help("status", "--help")
  assert_test(
    "Flag help extraction works",
    type(help_flag_help) == "string",
    "get_flag_help should return a string"
  )

  -- Since we added descriptions for common flags, --help should have one
  assert_test(
    "--help flag has description",
    help_flag_help ~= "",
    "--help flag should have a description"
  )
end

-- Test 5: Test parsing commands with descriptions
if completion_module then
  -- Clear cache and reparse to make sure we get the new format
  completion_module.clear_cache()

  -- Test completion with new structure
  local completions = completion_module.complete("st", "J st", 4)
  assert_test(
    "Completion still works with new parsing",
    type(completions) == "table" and #completions > 0,
    "Completion should still work with enhanced parsing"
  )

  local has_status = vim.tbl_contains(completions, "status")
  assert_test(
    "Status command still in completions",
    has_status,
    "status command should still appear in completions"
  )
end

-- Test 6: Test inline help display function
if completion_module then
  local success = pcall(function()
    local help_win = completion_module.show_inline_help("J ")
    -- Check if window was created
    if help_win and vim.api.nvim_win_is_valid(help_win) then
      vim.api.nvim_win_close(help_win, true) -- Close immediately for test
    end
  end)

  assert_test(
    "Inline help display works for commands",
    success,
    "show_inline_help should work for command context"
  )

  -- Test with flag context
  local success_flags = pcall(function()
    local help_win = completion_module.show_inline_help("J status ")
    if help_win and vim.api.nvim_win_is_valid(help_win) then
      vim.api.nvim_win_close(help_win, true) -- Close immediately for test
    end
  end)

  assert_test(
    "Inline help display works for flags",
    success_flags,
    "show_inline_help should work for flag context"
  )
end

-- Test 7: Check that JHelp command was created
local jhelp_exists = false
for _, cmd in ipairs(vim.api.nvim_get_commands({})) do
  if cmd[1] == "JHelp" then
    jhelp_exists = true
    break
  end
end

assert_test("JHelp command created", jhelp_exists, "JHelp command should be available")

-- Test 8: Check that JHelpPopup command was created
local jhelpPopup_exists = false
for _, cmd in ipairs(vim.api.nvim_get_commands({})) do
  if cmd[1] == "JHelpPopup" then
    jhelpPopup_exists = true
    break
  end
end

assert_test(
  "JHelpPopup command created",
  jhelpPopup_exists,
  "JHelpPopup command should be available"
)

-- Test 9: Test JHelp command execution
if jhelp_exists then
  local success = pcall(function()
    vim.cmd("JHelp")
  end)

  assert_test("JHelp command executes", success, "JHelp command should execute without error")

  -- Clean up any help windows
  vim.defer_fn(function()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      local bufname = vim.api.nvim_buf_get_name(buf)
      if bufname:match("help") or vim.api.nvim_win_get_config(win).relative ~= "" then
        pcall(vim.api.nvim_win_close, win, true)
      end
    end
  end, 100)
end

-- Test 10: Test enhanced parsing robustness
if completion_module then
  -- Test that old completion behavior still works
  local old_style_completions = completion_module.complete("", "J ", 2)
  assert_test(
    "Backward compatibility maintained",
    type(old_style_completions) == "table" and #old_style_completions > 0,
    "Old-style completion should still work"
  )

  -- Test flag completion still works
  local flag_completions = completion_module.complete("--", "J status --", 10)
  assert_test(
    "Flag completion still works",
    type(flag_completions) == "table",
    "Flag completion should still work with enhanced parsing"
  )
end

-- Summary
print("\n📊 === Inline Help Test Results Summary ===")
local passed = 0
local total = #test_results

for _, result in ipairs(test_results) do
  if result.passed then
    passed = passed + 1
  end
end

print(string.format("Passed: %d/%d tests", passed, total))

if passed == total then
  print("🎉 All inline help tests passed!")
  print("✅ Inline help functionality with --help extraction works correctly")
  print("")
  print("Usage:")
  print("  :JHelp          - Show help for all commands")
  print("  :JHelp status   - Show help for status command flags")
  print("  :JHelpPopup     - Show help for current command line (during :J input)")
  os.exit(0)
else
  print("💥 Some inline help tests failed!")
  for _, result in ipairs(test_results) do
    if not result.passed then
      print("  ❌ " .. result.name .. ": " .. (result.message or ""))
    end
  end
  os.exit(1)
end
