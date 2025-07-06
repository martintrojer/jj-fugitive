#!/usr/bin/env -S nvim --headless -l

local runner = require("tests.test_runner")
runner.init("CI Debug Test")

runner.section("Environment Information")
runner.info("Working directory: " .. vim.fn.getcwd())
runner.info("Neovim version: " .. tostring(vim.version()))

-- Check file system
runner.info("Directory contents:")
local files = vim.fn.glob("*", false, true)
for _, file in ipairs(files) do
  runner.info("  " .. file)
end

runner.section("jj CLI Tool Availability")
-- Check if jj is available
local jj_version = vim.fn.system("jj --version")
local jj_exit_code = vim.v.shell_error
runner.info("jj version check:")
if jj_exit_code == 0 then
  runner.info("jj available: " .. jj_version:gsub("\n", ""))
  runner.assert_test("jj CLI tool is available", true)
else
  runner.info("jj not available, exit code: " .. jj_exit_code)
  runner.info("Output: " .. jj_version)
  runner.assert_test("jj CLI tool is available", false, "jj command not found or failed")
end

runner.section("Basic jj Commands")
-- Test if we can run basic commands
local status_ok, result = pcall(function()
  return vim.fn.system("jj status")
end)

if status_ok then
  runner.info("jj status command works")
  runner.info("Output: " .. result:sub(1, 200) .. (result:len() > 200 and "..." or ""))
  runner.assert_test("jj status command execution", true)
else
  runner.info("jj status failed")
  runner.info("Error: " .. tostring(result))
  runner.assert_test("jj status command execution", false, "jj status command failed")
end

runner.section("Plugin Loading")
-- Plugin is already loaded by runner.init(), so we test if we can access modules
local init_module = runner.load_module("jj-fugitive.init")

if init_module then
  runner.section("Plugin Functionality")
  local test_ok, test_error = pcall(function()
    local repo_root = init_module.get_repo_root()
    runner.info("Repository root: " .. (repo_root or "nil"))
    return repo_root ~= nil
  end)

  runner.assert_test(
    "Repository root detection",
    test_ok and test_error,
    "Failed to get repository root"
  )
end

runner.finish({
  "🎉 CI debug test completed",
  "✅ Environment diagnostics successful",
})
