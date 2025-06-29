#!/usr/bin/env -S nvim --headless -l

-- Test repository detection functionality
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

print("🚀 === jj-fugitive Repository Detection Tests ===")

-- Test 1: Load the main module
local main_module = nil
pcall(function()
  main_module = require("jj-fugitive.init")
end)
assert_test("Main module loading", main_module ~= nil, "Could not require jj-fugitive.init")

if main_module then
  -- Test 2: Test repository root detection from current directory
  local repo_root = main_module.get_repo_root()
  assert_test("Repository root detection", repo_root ~= nil, "Could not detect repository root")

  if repo_root then
    print("Repository root detected:", repo_root)
    print("Current working directory:", vim.fn.getcwd())
    
    -- Test 3: Test running a simple jj command
    local result = main_module.run_jj_command_from_module({"status"})
    assert_test("jj status command execution", result ~= nil, "jj status command failed")
    
    -- Test 4: Test log command specifically
    local log_result = main_module.run_jj_command_from_module({"log", "--limit", "2"})
    assert_test("jj log command execution", log_result ~= nil, "jj log command failed")
    
    -- Test 5: Test from a subdirectory (the key issue that was reported)
    print("\n=== Testing from subdirectory (original reported issue) ===")
    local original_cwd = vim.fn.getcwd()
    
    -- Change to lua subdirectory
    vim.cmd("cd lua")
    local sub_cwd = vim.fn.getcwd()
    print("Changed to:", sub_cwd)
    
    local sub_repo_root = main_module.get_repo_root()
    assert_test("Repository root detection from subdirectory", 
                sub_repo_root ~= nil, 
                "Could not detect repository root from subdirectory")
    
    if sub_repo_root then
      assert_test("Repository root consistency", 
                  sub_repo_root == repo_root,
                  "Repository root differs when detected from subdirectory")
      
      local sub_result = main_module.run_jj_command_from_module({"status"})
      assert_test("jj status from subdirectory", 
                  sub_result ~= nil, 
                  "jj status failed from subdirectory")
      
      local sub_log_result = main_module.run_jj_command_from_module({"log", "--limit", "1"})
      assert_test("jj log from subdirectory", 
                  sub_log_result ~= nil, 
                  "jj log failed from subdirectory")
    end
    
    -- Restore original directory
    vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))
    
    -- Test 6: Test from nested subdirectory
    if vim.fn.isdirectory("lua/jj-fugitive") == 1 then
      print("\n=== Testing from nested subdirectory ===")
      vim.cmd("cd lua/jj-fugitive")
      local nested_cwd = vim.fn.getcwd()
      print("Changed to nested directory:", nested_cwd)
      
      local nested_repo_root = main_module.get_repo_root()
      assert_test("Repository root detection from nested subdirectory", 
                  nested_repo_root ~= nil, 
                  "Could not detect repository root from nested subdirectory")
      
      if nested_repo_root then
        assert_test("Repository root consistency from nested directory", 
                    nested_repo_root == repo_root,
                    "Repository root differs when detected from nested subdirectory")
        
        local nested_result = main_module.run_jj_command_from_module({"status"})
        assert_test("jj status from nested subdirectory", 
                    nested_result ~= nil, 
                    "jj status failed from nested subdirectory")
      end
      
      -- Restore original directory
      vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))
    end
  end
end

-- Summary
print("\n📊 === Repository Detection Test Results Summary ===")
local passed = 0
local total = #test_results

for _, result in ipairs(test_results) do
  if result.passed then
    passed = passed + 1
  end
end

print(string.format("Passed: %d/%d tests", passed, total))

if passed == total then
  print("🎉 All repository detection tests passed!")
  print("✅ The original issue with subdirectory execution should be fixed")
  os.exit(0)
else
  print("💥 Some repository detection tests failed!")
  for _, result in ipairs(test_results) do
    if not result.passed then
      print("  ❌ " .. result.name .. ": " .. (result.message or ""))
    end
  end
  os.exit(1)
end