#!/usr/bin/env lua

--[[
Remote API Test for jj-fugitive

This script tests the jj-fugitive plugin using Neovim's remote API
without requiring interactive use. It starts a headless Neovim instance
and communicates with it via RPC.

Usage:
  lua tests/remote_api_test.lua

Requirements:
  - Neovim with --listen support
  - jj repository for testing
  - lua-cjson or similar for JSON parsing (optional)
--]]

local socket_path = "/tmp/nvim_jj_fugitive_test.sock"

-- Helper function to run shell commands and capture output
local function run_command(cmd)
  local handle = io.popen(cmd)
  local output = handle:read("*a")
  local success = handle:close()
  return output:gsub("\n$", ""), success
end

-- Start headless Neovim with plugin loaded
local function start_neovim()
  print("Starting headless Neovim with jj-fugitive...")

  -- Remove old socket if it exists
  os.remove(socket_path)

  -- Start Neovim in background with our plugin
  local cmd = string.format(
    "nvim --headless --listen %s --cmd 'set rtp+=.' -c 'runtime plugin/jj-fugitive.lua' &",
    socket_path
  )

  os.execute(cmd)

  -- Wait for socket to be created
  local retries = 0
  while retries < 50 do
    local socket_exists = os.execute("test -S " .. socket_path) == 0
    if socket_exists then
      print("Neovim started successfully")
      return true
    end
    os.execute("sleep 0.1")
    retries = retries + 1
  end

  error("Failed to start Neovim or create socket")
end

-- Execute a command in the remote Neovim instance
local function nvim_command(cmd)
  local remote_cmd = string.format(
    "nvim --server %s --remote-expr 'execute(\"%s\")'",
    socket_path,
    cmd:gsub('"', '\\"')
  )
  return run_command(remote_cmd)
end

-- Execute Lua code in the remote Neovim instance
local function nvim_lua(lua_code)
  local remote_cmd = string.format(
    "nvim --server %s --remote-expr 'luaeval(\"%s\")'",
    socket_path,
    lua_code:gsub('"', '\\"')
  )
  return run_command(remote_cmd)
end

-- Get buffer contents from remote Neovim
local function get_buffer_lines(bufnr)
  bufnr = bufnr or 0
  local lua_code =
    string.format("table.concat(vim.api.nvim_buf_get_lines(%d, 0, -1, false), '\\\\n')", bufnr)
  return nvim_lua(lua_code)
end

-- Get list of all buffers
local function get_buffers()
  local lua_code = "table.concat(vim.api.nvim_list_bufs(), ',')"
  local result = nvim_lua(lua_code)
  local buffers = {}
  for buf in result:gmatch("([^,]+)") do
    table.insert(buffers, tonumber(buf))
  end
  return buffers
end

-- Find buffer by name pattern
local function find_buffer_by_name(pattern)
  local lua_code = string.format(
    [[
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      local name = vim.api.nvim_buf_get_name(buf)
      if name:match('%s') then
        return buf
      end
    end
    return -1
  ]],
    pattern
  )

  local result = nvim_lua(lua_code)
  local bufnr = tonumber(result)
  return bufnr ~= -1 and bufnr or nil
end

-- Clean up: kill Neovim and remove socket
local function cleanup()
  print("Cleaning up...")

  -- Try to quit Neovim gracefully
  pcall(function()
    nvim_command("qall!")
  end)

  -- Remove socket
  os.remove(socket_path)

  -- Force kill any remaining nvim processes (be careful!)
  os.execute("pkill -f 'nvim.*" .. socket_path .. "' 2>/dev/null")
end

-- Test the :JStatus command
local function test_jstatus()
  print("\n=== Testing :JStatus command ===")

  -- Execute :JStatus command
  print("Executing :JStatus...")
  local _, success = nvim_command("JStatus")

  if not success then
    error("Failed to execute :JStatus command")
  end

  -- Wait a moment for buffer to be created
  os.execute("sleep 0.5")

  -- Look for the jj-status buffer
  local status_buf = find_buffer_by_name("jj%-status")

  if not status_buf then
    print("WARNING: Could not find jj-status buffer")
    -- List all buffers for debugging
    local buffers = get_buffers()
    print("Available buffers:")
    for _, buf in ipairs(buffers) do
      local name_cmd = string.format("vim.api.nvim_buf_get_name(%d)", buf)
      local name = nvim_lua(name_cmd)
      print(string.format("  Buffer %d: %s", buf, name))
    end
    return false
  end

  print(string.format("Found jj-status buffer: %d", status_buf))

  -- Get buffer contents
  local content = get_buffer_lines(status_buf)
  print("Status buffer content:")
  print("--- START ---")
  print(content)
  print("--- END ---")

  -- Validate content contains expected elements
  local validations = {
    "jj%-fugitive Status",
    "Working copy",
    "Commands:",
  }

  local all_valid = true
  for _, pattern in ipairs(validations) do
    if not content:match(pattern) then
      print(string.format("FAIL: Missing expected pattern: %s", pattern))
      all_valid = false
    else
      print(string.format("PASS: Found pattern: %s", pattern))
    end
  end

  return all_valid
end

-- Test plugin loading
local function test_plugin_loading()
  print("\n=== Testing plugin loading ===")

  -- Check if our commands are available
  local commands_to_test = { "JStatus", "JLog", "JDiff", "JCommit" }

  for _, cmd in ipairs(commands_to_test) do
    local check_cmd = string.format("exists(':%s')", cmd)
    local result = nvim_command(check_cmd)

    if result:match("1") then
      print(string.format("PASS: Command :%s is available", cmd))
    else
      print(string.format("FAIL: Command :%s is not available", cmd))
      return false
    end
  end

  return true
end

-- Test that we're in a jj repository
local function test_jj_repo()
  print("\n=== Testing jj repository ===")

  local jj_status, success = run_command("jj status")

  if not success then
    print("FAIL: Not in a jj repository or jj command failed")
    print("Output:", jj_status)
    return false
  end

  print("PASS: In a valid jj repository")
  print("jj status output:", jj_status:sub(1, 100) .. "...")
  return true
end

-- Main test runner
local function run_tests()
  print("=== jj-fugitive Remote API Tests ===")

  local tests = {
    { "jj repository", test_jj_repo },
    { "plugin loading", test_plugin_loading },
    { ":JStatus command", test_jstatus },
  }

  local passed = 0
  local total = #tests

  for _, test in ipairs(tests) do
    local name, func = test[1], test[2]
    print(string.format("\nRunning test: %s", name))

    local success, result = pcall(func)

    if success and result then
      print(string.format("✅ PASS: %s", name))
      passed = passed + 1
    else
      print(string.format("❌ FAIL: %s", name))
      if not success then
        print("Error:", result)
      end
    end
  end

  print(string.format("\n=== Test Results ==="))
  print(string.format("Passed: %d/%d", passed, total))

  if passed == total then
    print("🎉 All tests passed!")
    return 0
  else
    print("💥 Some tests failed!")
    return 1
  end
end

-- Signal handler for cleanup
local function signal_handler() -- luacheck: ignore
  cleanup()
  os.exit(1)
end

-- Set up signal handling (Unix-like systems)
if os.execute("which trap >/dev/null 2>&1") == 0 then
  os.execute('trap \'lua -e "require(\\"os\\").remove(\\"' .. socket_path .. '\\")"\' EXIT')
end

-- Main execution
local function main()
  -- Ensure we cleanup on exit
  local success, result = pcall(function()
    start_neovim()

    -- Give Neovim time to fully load
    os.execute("sleep 1")

    return run_tests()
  end)

  cleanup()

  if not success then
    print("Error during test execution:", result)
    return 1
  end

  return result or 0
end

-- Run if executed directly
if arg and arg[0] and arg[0]:match("remote_api_test%.lua$") then
  local exit_code = main()
  os.exit(exit_code)
end

-- Export functions for use as module
return {
  start_neovim = start_neovim,
  cleanup = cleanup,
  nvim_command = nvim_command,
  nvim_lua = nvim_lua,
  test_jstatus = test_jstatus,
  run_tests = run_tests,
}
