#!/usr/bin/env -S nvim --headless -l

local runner = require("tests.test_runner")

runner.init("jj-fugitive User Experience Simulation")

-- Test 1: Load all core modules
local status_module = runner.load_module("jj-fugitive.status")
local log_module = runner.load_module("jj-fugitive.log")
local diff_module = runner.load_module("jj-fugitive.diff")

-- Test 2: Simulate basic user workflow
runner.section("Workflow simulation: Status → File diff → Log")

if status_module then
  pcall(status_module.show_status)
  local status_buf = runner.find_buffer("jj%-status")
  runner.assert_test(
    "User can open status view",
    status_buf ~= nil,
    "Status view should be accessible"
  )
end

if diff_module then
  local test_file = "user_test.txt"
  runner.create_test_file(test_file, "User test content")

  pcall(function()
    diff_module.show_file_diff(test_file)
  end)

  local diff_buf = runner.find_buffer("jj%-diff")
  runner.assert_test("User can view file diffs", diff_buf ~= nil, "File diff should be accessible")

  pcall(function()
    os.remove(test_file)
  end)
end

if log_module then
  pcall(function()
    log_module.show_log({ limit = 5 })
  end)

  local log_buf = runner.find_buffer("jj%-log")
  runner.assert_test("User can view commit log", log_buf ~= nil, "Log view should be accessible")
end

-- Test 3: Key workflow verification
runner.section("User experience verification")

runner.assert_test(
  "Complete workflow available",
  status_module and log_module and diff_module,
  "All core views should be available"
)

-- Test 4: User-friendly features
local jj_status = vim.fn.system({ "jj", "status" })
runner.assert_test(
  "Repository state accessible",
  jj_status ~= nil and jj_status ~= "",
  "User should be able to see repository state"
)

local jj_log = vim.fn.system({ "jj", "log", "--limit", "3" })
runner.assert_test(
  "History accessible",
  jj_log ~= nil and jj_log ~= "",
  "User should be able to see commit history"
)

runner.finish("✨ jj-fugitive provides smooth user experience")
