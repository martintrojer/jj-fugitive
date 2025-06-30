#!/usr/bin/env -S nvim --headless -l

-- Even simpler test for CI debugging
print("🔍 Simple Debug Test")
print("✅ Test executed successfully")
print("📍 Working directory: " .. vim.fn.getcwd())

-- Check basic jj functionality
local jj_version = vim.fn.system("jj --version")
if vim.v.shell_error == 0 then
  print("✅ jj command works: " .. jj_version:gsub("\n", ""))
else
  print("❌ jj command failed")
end

print("🎉 Simple debug test completed")