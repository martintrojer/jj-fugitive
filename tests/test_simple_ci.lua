#!/usr/bin/env -S nvim --headless -l

-- Simple CI test
print("🚀 Simple CI Test Starting")
print("✅ Lua execution works")

-- Test basic system command
local jj_result = os.execute("jj --version")
if jj_result == 0 then
  print("✅ jj command available")
else
  print("❌ jj command failed with code: " .. tostring(jj_result))
end

print("🎉 Simple CI test completed")