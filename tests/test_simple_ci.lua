#!/usr/bin/env -S nvim --headless -l

-- Simple CI test using common test runner
local runner = require("tests.test_runner")

runner.init("Simple CI Test")

-- Test Neovim Lua execution by verifying basic API works
local nvim_version = vim.version()
runner.assert_test(
  "Neovim Lua API works",
  nvim_version ~= nil and nvim_version.major >= 0,
  "vim.version() should return valid version"
)

-- Test basic system command
local jj_result = os.execute("jj --version > /dev/null 2>&1")
runner.assert_test("jj command available", jj_result == 0, "jj command failed")

runner.finish("Simple CI test completed")
