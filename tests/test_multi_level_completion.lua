#!/usr/bin/env -S nvim --headless -l

-- Test multi-level completion functionality (commands and flags at every nesting level)
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

print("🚀 === Multi-Level Completion Tests ===")

local completion = require("jj-fugitive.completion")

-- Test 1: Level 1 - Basic commands ":J "
print("\n🧪 Test 1: Level 1 - Basic commands")
local level1_result = completion.complete("", "J ", 2)
assert_test(
  "Level 1 includes commands",
  #level1_result > 0,
  "Should return available commands at level 1"
)

-- Check for mix of commands
local has_git = vim.tbl_contains(level1_result, "git")
local has_status = vim.tbl_contains(level1_result, "status")
local has_log = vim.tbl_contains(level1_result, "log")
assert_test(
  "Level 1 includes expected commands",
  has_git and has_status and has_log,
  "Should include git, status, and log commands"
)

-- Test 2: Level 2 - Git subcommands ":J git "
print("\n🧪 Test 2: Level 2 - Git subcommands")
local level2_git_result = completion.complete("", "J git ", 6)
assert_test(
  "Level 2 git includes subcommands",
  #level2_git_result > 0,
  "Should return git subcommands at level 2"
)

-- Check for git subcommands (not flags)
local expected_git_subcmds = { "push", "fetch", "clone", "remote" }
local found_git_subcmds = 0
for _, expected in ipairs(expected_git_subcmds) do
  if vim.tbl_contains(level2_git_result, expected) then
    found_git_subcmds = found_git_subcmds + 1
  end
end
assert_test(
  "Level 2 git shows subcommands not flags",
  found_git_subcmds >= 2,
  string.format(
    "Should find git subcommands. Found %d of: %s",
    found_git_subcmds,
    table.concat(expected_git_subcmds, ", ")
  )
)

-- Test 3: Level 2 - Bookmark subcommands ":J bookmark "
print("\n🧪 Test 3: Level 2 - Bookmark subcommands")
local level2_bookmark_result = completion.complete("", "J bookmark ", 11)

-- CI Debug: Show bookmark completion results
if os.getenv("CI") then
  print("CI DEBUG: Level 2 bookmark completion results:")
  for i, result in ipairs(level2_bookmark_result) do
    print(string.format("  [%d] %s", i, result))
  end
  print(string.format("CI DEBUG: Total bookmark results: %d", #level2_bookmark_result))
end

assert_test(
  "Level 2 bookmark includes subcommands",
  #level2_bookmark_result > 0,
  "Should return bookmark subcommands at level 2"
)

-- Check for bookmark subcommands
local expected_bookmark_subcmds = { "list", "create", "delete", "set" }
local found_bookmark_subcmds = 0
for _, expected in ipairs(expected_bookmark_subcmds) do
  if vim.tbl_contains(level2_bookmark_result, expected) then
    found_bookmark_subcmds = found_bookmark_subcmds + 1
  end
end

-- CI Debug: Show which bookmark subcommands were found
if os.getenv("CI") then
  print("CI DEBUG: Bookmark subcommand search results:")
  for _, expected in ipairs(expected_bookmark_subcmds) do
    local found = vim.tbl_contains(level2_bookmark_result, expected)
    print(string.format("  %s: %s", expected, found and "FOUND" or "NOT FOUND"))
  end
  print(
    string.format(
      "CI DEBUG: Found %d/%d bookmark subcommands",
      found_bookmark_subcmds,
      #expected_bookmark_subcmds
    )
  )
end

assert_test(
  "Level 2 bookmark shows subcommands",
  found_bookmark_subcmds >= 2,
  string.format(
    "Should find bookmark subcommands. Found %d of: %s",
    found_bookmark_subcmds,
    table.concat(expected_bookmark_subcmds, ", ")
  )
)

-- Test 4: Level 2 - Regular command flags ":J status "
print("\n🧪 Test 4: Level 2 - Regular command flags")
local level2_status_result = completion.complete("", "J status ", 9)
assert_test(
  "Level 2 status includes flags",
  #level2_status_result > 0,
  "Should return status command flags at level 2"
)

-- Check for flags (should start with -)
local status_flags_count = 0
for _, item in ipairs(level2_status_result) do
  if item:match("^%-") then
    status_flags_count = status_flags_count + 1
  end
end
assert_test(
  "Level 2 status shows flags not subcommands",
  status_flags_count > 0,
  string.format("Should find flags starting with '-'. Found %d flags", status_flags_count)
)

-- Test 5: Level 3 - Git subcommand flags ":J git push "
print("\n🧪 Test 5: Level 3 - Git subcommand flags")
local level3_git_push_result = completion.complete("", "J git push ", 11)
assert_test(
  "Level 3 git push includes flags",
  #level3_git_push_result > 0,
  "Should return git push flags at level 3"
)

-- Check for flags in git push results
local git_push_flags_count = 0
for _, item in ipairs(level3_git_push_result) do
  if item:match("^%-") then
    git_push_flags_count = git_push_flags_count + 1
  end
end
assert_test(
  "Level 3 git push shows flags",
  git_push_flags_count > 0,
  string.format("Should find git push flags. Found %d flags", git_push_flags_count)
)

-- Test 6: Level 3 - Bookmark subcommand flags ":J bookmark create "
print("\n🧪 Test 6: Level 3 - Bookmark subcommand flags")
local level3_bookmark_create_result = completion.complete("", "J bookmark create ", 18)

-- CI Debug: Show bookmark create completion results
if os.getenv("CI") then
  print("CI DEBUG: Level 3 bookmark create completion results:")
  for i, result in ipairs(level3_bookmark_create_result) do
    print(string.format("  [%d] %s", i, result))
  end
  print(
    string.format("CI DEBUG: Total bookmark create results: %d", #level3_bookmark_create_result)
  )
end

assert_test(
  "Level 3 bookmark create includes flags",
  #level3_bookmark_create_result > 0,
  "Should return bookmark create flags at level 3"
)

-- Check for flags in bookmark create results
local bookmark_create_flags_count = 0
for _, item in ipairs(level3_bookmark_create_result) do
  if item:match("^%-") then
    bookmark_create_flags_count = bookmark_create_flags_count + 1
  end
end

-- CI Debug: Show flag analysis results
if os.getenv("CI") then
  print("CI DEBUG: Bookmark create flag analysis:")
  for _, item in ipairs(level3_bookmark_create_result) do
    local is_flag = item:match("^%-") and true or false
    print(string.format("  %s: %s", item, is_flag and "FLAG" or "NOT FLAG"))
  end
  print(
    string.format(
      "CI DEBUG: Found %d flags out of %d total results",
      bookmark_create_flags_count,
      #level3_bookmark_create_result
    )
  )
end

assert_test(
  "Level 3 bookmark create shows flags",
  bookmark_create_flags_count > 0,
  string.format("Should find bookmark create flags. Found %d flags", bookmark_create_flags_count)
)

-- Test 7: Commands vs subcommands distinction
print("\n🧪 Test 7: Commands vs subcommands distinction")
local git_subcommands = completion.complete("", "J git ", 6)
local status_flags = completion.complete("", "J status ", 9)

-- Git should show subcommands, status should show flags
local git_has_subcommands = vim.tbl_contains(git_subcommands, "push")
  or vim.tbl_contains(git_subcommands, "fetch")
local status_has_flags = false
for _, item in ipairs(status_flags) do
  if item:match("^%-") then
    status_has_flags = true
    break
  end
end

assert_test(
  "Commands with subcommands show subcommands",
  git_has_subcommands,
  "Git should show subcommands like push, fetch"
)
assert_test(
  "Regular commands show flags",
  status_has_flags,
  "Status should show flags starting with '-'"
)

-- Test 8: No cross-pollution between levels
print("\n🧪 Test 8: No cross-pollution between levels")
local git_level2 = completion.complete("", "J git ", 6)

-- Git level 2 should not include git push flags
local git_level2_has_flags = false
for _, item in ipairs(git_level2) do
  if item:match("^%-%-bookmark") or item:match("^%-%-branch") then
    git_level2_has_flags = true
    break
  end
end

assert_test(
  "No cross-pollution between levels",
  not git_level2_has_flags,
  "Git level 2 should not show git push specific flags"
)

-- Test 9: Partial matching works at all levels
print("\n🧪 Test 9: Partial matching at all levels")
local git_p_partial = completion.complete("p", "J git p", 7)
local status_help_partial = completion.complete("--h", "J status --h", 12)

-- All git partial results should start with 'p'
local git_p_correct = true
for _, item in ipairs(git_p_partial) do
  if not item:match("^p") then
    git_p_correct = false
    break
  end
end

-- All status partial results should start with '--h'
local status_h_correct = true
for _, item in ipairs(status_help_partial) do
  if not item:match("^%-%-h") then
    status_h_correct = false
    break
  end
end

assert_test(
  "Partial matching works for git subcommands",
  git_p_correct,
  "All git completions for 'p' should start with 'p'"
)
assert_test(
  "Partial matching works for status flags",
  status_h_correct,
  "All status completions for '--h' should start with '--h'"
)

-- Test 10: Help flags available at all levels
print("\n🧪 Test 10: Help flags available at all levels")
local status_help = vim.tbl_contains(level2_status_result, "--help")
  or vim.tbl_contains(level2_status_result, "-h")
local git_push_help = vim.tbl_contains(level3_git_push_result, "--help")
  or vim.tbl_contains(level3_git_push_result, "-h")

assert_test(
  "Help flags available at level 2",
  status_help,
  "Status command should include --help or -h flag"
)
assert_test(
  "Help flags available at level 3",
  git_push_help,
  "Git push command should include --help or -h flag"
)

-- Summary
print("\n📊 === Multi-Level Completion Test Results Summary ===")
local passed = 0
local total = #test_results

for _, result in ipairs(test_results) do
  if result.passed then
    passed = passed + 1
  end
end

print(string.format("Passed: %d/%d tests", passed, total))

if passed == total then
  print("🎉 All multi-level completion tests passed!")
  print("✅ Completion works at every nesting level with appropriate commands and flags")
  print("")
  print("Verified functionality:")
  print("  • Level 1: :J <Tab> → main commands")
  print("  • Level 2: :J git <Tab> → git subcommands")
  print("  • Level 2: :J status <Tab> → status flags")
  print("  • Level 3: :J git push <Tab> → git push flags")
  print("  • Level 3: :J bookmark create <Tab> → bookmark create flags")
  print("  • Partial matching works at all levels")
  print("  • No cross-pollution between command types")
  print("  • Help flags available at all levels")
  os.exit(0)
else
  print("💥 Some multi-level completion tests failed!")
  for _, result in ipairs(test_results) do
    if not result.passed then
      print("  ❌ " .. result.name .. ": " .. (result.message or ""))
    end
  end
  os.exit(1)
end
