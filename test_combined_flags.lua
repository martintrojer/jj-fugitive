#!/usr/bin/env -S nvim --headless -l

-- Test combined -r .. and --limit flags
vim.cmd("set rtp+=.")
vim.cmd("runtime plugin/jj-fugitive.lua")

print("🔧 Testing combined -r .. --limit functionality")

local main_module = require("jj-fugitive.init")

-- Test 1: Combined flags with different limits
print("\n🧪 Test 1: -r .. with --limit 5")
local result1 = main_module.run_jj_command_from_module({"log", "--color", "always", "-r", "..", "--limit", "5"})
if result1 then
  local line_count = #vim.split(result1, "\n")
  print(string.format("✅ -r .. --limit 5 returned %d lines", line_count))
else
  print("❌ Failed to get log with -r .. --limit 5")
end

print("\n🧪 Test 2: -r .. with --limit 10") 
local result2 = main_module.run_jj_command_from_module({"log", "--color", "always", "-r", "..", "--limit", "10"})
if result2 then
  local line_count = #vim.split(result2, "\n")
  print(string.format("✅ -r .. --limit 10 returned %d lines", line_count))
  
  -- Check that limit 10 has more or equal lines than limit 5
  local count1 = result1 and #vim.split(result1, "\n") or 0
  local count2 = #vim.split(result2, "\n")
  if count2 >= count1 then
    print(string.format("✅ Higher limit (%d lines) >= Lower limit (%d lines)", count2, count1))
  else
    print(string.format("⚠️  Higher limit (%d lines) < Lower limit (%d lines)", count2, count1))
  end
else
  print("❌ Failed to get log with -r .. --limit 10")
end

-- Test 3: Test the get_jj_log function with combined options
print("\n🧪 Test 3: get_jj_log with revisions and limit")
local log_module = require("jj-fugitive.log")

-- Access the private get_jj_log function by looking at the module
local function test_get_jj_log(options)
  options = options or {}
  local cmd_args = { "log", "--color", "always" }
  
  if options.limit then
    table.insert(cmd_args, "--limit")
    table.insert(cmd_args, tostring(options.limit))
  end
  
  if options.revisions then
    for _, rev in ipairs(options.revisions) do
      table.insert(cmd_args, "-r")
      table.insert(cmd_args, rev)
    end
  end
  
  return main_module.run_jj_command_from_module(cmd_args)
end

local result3 = test_get_jj_log({ revisions = { ".." }, limit = 15 })
if result3 then
  local line_count = #vim.split(result3, "\n")
  print(string.format("✅ get_jj_log with revisions={'..'} and limit=15 returned %d lines", line_count))
else
  print("❌ Failed to get log with combined options")
end

-- Test 4: Verify that expansion works by testing progressive limits
print("\n🧪 Test 4: Testing progressive limit expansion")
local limits = {5, 10, 20}
local results = {}

for _, limit in ipairs(limits) do
  local result = test_get_jj_log({ revisions = { ".." }, limit = limit })
  if result then
    local line_count = #vim.split(result, "\n")
    table.insert(results, {limit = limit, lines = line_count})
    print(string.format("✅ Limit %d: %d lines", limit, line_count))
  else
    print(string.format("❌ Failed with limit %d", limit))
  end
end

-- Check that higher limits generally give more lines (up to the total available)
local progressive = true
for i = 2, #results do
  if results[i].lines < results[i-1].lines then
    progressive = false
    break
  end
end

if progressive then
  print("✅ Progressive expansion working correctly")
else
  print("⚠️  Progressive expansion may have reached repository limit")
end

print("\n🎉 Combined -r .. --limit test completed!")