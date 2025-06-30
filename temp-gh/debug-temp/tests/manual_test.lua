-- Manual test script for debugging :J status issues
-- Run with: nvim --cmd "set rtp+=." -l tests/manual_test.lua

-- Load the plugin
vim.cmd("runtime plugin/jj-fugitive.lua")

print("=== Manual Test: J status functionality ===")

-- Test 1: Create status buffer
print("Test 1: Creating status buffer...")
vim.cmd("J status")

-- Wait a moment
vim.loop.sleep(500)

-- Check buffers
local found_buffer = nil
for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
  if vim.api.nvim_buf_is_valid(bufnr) then
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name:match("jj%-status") then
      found_buffer = bufnr
      break
    end
  end
end

if found_buffer then
  print("✅ Found status buffer:", found_buffer)
  local lines = vim.api.nvim_buf_get_lines(found_buffer, 0, -1, false)
  print("Buffer has", #lines, "lines")
  print("First few lines:", vim.inspect(vim.list_slice(lines, 1, 3)))

  -- Test 2: Try to reload content
  print("\nTest 2: Testing reload function...")

  -- Set the buffer as current
  vim.api.nvim_set_current_buf(found_buffer)

  -- Get the reload function
  local status_module = require("jj-fugitive.status")

  print("Calling show_status() again...")
  status_module.show_status()

  print("✅ Reload completed")
else
  print("❌ No status buffer found")
  print("Available buffers:")
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local name = vim.api.nvim_buf_get_name(bufnr)
      print("  Buffer", bufnr, ":", name)
    end
  end
end

print("=== Test completed ===")

-- Exit
vim.cmd("qall!")
