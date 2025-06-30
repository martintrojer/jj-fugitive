#!/usr/bin/env -S nvim --headless -l

-- Simple CI debugging test
print("🔍 CI Debug Test Starting")
print("📍 Working directory: " .. vim.fn.getcwd())

-- Test if we can run basic commands
local status_ok, result = pcall(function()
  return vim.fn.system("jj status")
end)

if status_ok then
  print("✅ jj status command works")
  print("📄 Output: " .. result)
else
  print("❌ jj status failed")
  print("❌ Error: " .. tostring(result))
end

-- Test if we can load our plugin
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

print("🎉 CI debug test completed")