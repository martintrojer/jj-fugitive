#!/usr/bin/env -S nvim --headless -l

local runner = require("tests.test_runner")

runner.init("jj-fugitive Status Enter/'l' Key Tests")

local status_module = runner.load_module("jj-fugitive.status")

-- Test 1: Create status buffer
if status_module then
  pcall(status_module.show_status)
end

local status_bufnr = runner.find_buffer("jj%-status")
runner.assert_test("Status buffer created", status_bufnr ~= nil, "Status buffer should exist")

-- Test 2: Enter key functionality
if status_bufnr then
  local enter_mapping = vim.fn.maparg("<CR>", "n", false, true)
  runner.assert_test(
    "Enter key mapped",
    enter_mapping and enter_mapping.buffer == 1,
    "Enter key should be mapped in status buffer"
  )
end

-- Test 3: 'l' key functionality (log view)
if status_bufnr then
  local l_mapping = vim.fn.maparg("l", "n", false, true)
  runner.assert_test(
    "'l' key mapped",
    l_mapping and l_mapping.buffer == 1,
    "'l' key should be mapped to show log view"
  )
end

-- Test 4: Integration verification
local log_module = runner.load_module("jj-fugitive.log")
runner.assert_test(
  "Log module available for 'l' key",
  log_module ~= nil,
  "Log module should be available for 'l' key integration"
)

runner.finish()
