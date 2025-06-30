#!/usr/bin/env -S nvim --headless -l

-- Simple CI debugging test
print("🔍 CI Debug Test Starting")
print("📍 Working directory: " .. vim.fn.getcwd())
print("📍 Neovim version: " .. tostring(vim.version()))

-- Check file system
print("📁 Directory contents:")
local files = vim.fn.glob("*", false, true)
for _, file in ipairs(files) do
  print("  " .. file)
end

-- Check if jj is available
local jj_version = vim.fn.system("jj --version")
local jj_exit_code = vim.v.shell_error
print("📦 jj version check:")
if jj_exit_code == 0 then
  print("✅ jj available: " .. jj_version:gsub("\n", ""))
else
  print("❌ jj not available, exit code: " .. jj_exit_code)
  print("❌ Output: " .. jj_version)
end

-- Test if we can run basic commands
local status_ok, result = pcall(function()
  return vim.fn.system("jj status")
end)

if status_ok then
  print("✅ jj status command works")
  print("📄 Output: " .. result:sub(1, 200) .. (result:len() > 200 and "..." or ""))
else
  print("❌ jj status failed")
  print("❌ Error: " .. tostring(result))
end

-- Test if we can load our plugin
print("🔌 Loading plugin...")
local plugin_ok, plugin_error = pcall(function()
  vim.cmd("set rtp+=.")
  vim.cmd("runtime plugin/jj-fugitive.lua")
end)

if plugin_ok then
  print("✅ Plugin loaded successfully")
else
  print("❌ Plugin loading failed")
  print("❌ Error: " .. tostring(plugin_error))
end

-- Test basic plugin functionality
if plugin_ok then
  print("🧪 Testing basic plugin functions...")
  local test_ok, test_error = pcall(function()
    local init_module = require("jj-fugitive.init")
    local repo_root = init_module.get_repo_root()
    print("✅ Repository root: " .. (repo_root or "nil"))
  end)

  if not test_ok then
    print("❌ Plugin function test failed: " .. tostring(test_error))
  end
end

print("🎉 CI debug test completed")
print("🎯 Exit code: 0")
