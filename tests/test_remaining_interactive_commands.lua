#!/usr/bin/env -S nvim --headless -l

local runner = require("tests.test_runner")

runner.init("jj-fugitive Remaining Interactive Commands Tests")

local main_module = runner.load_module("jj-fugitive")

-- Test 1: Extended interactive command detection
runner.assert_test(
  "New command detected as interactive",
  main_module.is_interactive_command({ "new" }),
  "new should be detected as interactive"
)

runner.assert_test(
  "Edit command detected as interactive",
  main_module.is_interactive_command({ "edit" }),
  "edit should be detected as interactive"
)

runner.assert_test(
  "Rebase command detected as interactive",
  main_module.is_interactive_command({ "rebase" }),
  "rebase should be detected as interactive"
)

-- Test 2: Commands with flags
runner.assert_test(
  "New with message not interactive",
  not main_module.is_interactive_command({ "new", "-m", "message" }),
  "new with message should not be interactive"
)

runner.assert_test(
  "Edit with revision not interactive",
  not main_module.is_interactive_command({ "edit", "abc123" }),
  "edit with revision should not be interactive"
)

-- Test 3: Non-interactive commands
runner.assert_test(
  "Show command not interactive",
  not main_module.is_interactive_command({ "show" }),
  "show should not be interactive"
)

runner.assert_test(
  "Diff command not interactive",
  not main_module.is_interactive_command({ "diff" }),
  "diff should not be interactive"
)

runner.finish()
