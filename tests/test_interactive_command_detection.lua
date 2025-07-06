#!/usr/bin/env -S nvim --headless -l

local runner = require("tests.test_runner")

runner.init("jj-fugitive Interactive Command Detection Tests")

local main_module = runner.load_module("jj-fugitive")

-- Test 1: Interactive commands detection
runner.assert_test(
  "Describe command detected as interactive",
  main_module.is_interactive_command({ "describe" }),
  "describe should be detected as interactive"
)

runner.assert_test(
  "Describe with -m flag not interactive",
  not main_module.is_interactive_command({ "describe", "-m", "message" }),
  "describe with message should not be interactive"
)

runner.assert_test(
  "Commit command detected as interactive",
  main_module.is_interactive_command({ "commit" }),
  "commit should be detected as interactive"
)

runner.assert_test(
  "Commit with -m flag not interactive",
  not main_module.is_interactive_command({ "commit", "-m", "message" }),
  "commit with message should not be interactive"
)

-- Test 2: Complex interactive commands
runner.info("Alternative: Use jj split -i in terminal for interactive split")
runner.assert_test(
  "Split command detected as interactive",
  main_module.is_interactive_command({ "split" }),
  "split should be detected as interactive"
)

runner.info("Alternative: Use jj diffedit in terminal for interactive diff editing")
runner.assert_test(
  "Diffedit command detected as interactive",
  main_module.is_interactive_command({ "diffedit" }),
  "diffedit should be detected as interactive"
)

runner.info("Alternative: Use jj resolve in terminal for interactive conflict resolution")
runner.assert_test(
  "Resolve command detected as interactive",
  main_module.is_interactive_command({ "resolve" }),
  "resolve should be detected as interactive"
)

runner.assert_test(
  "Resolve with --list flag not interactive",
  not main_module.is_interactive_command({ "resolve", "--list" }),
  "resolve --list should not be interactive"
)

-- Test 3: Non-interactive commands
runner.assert_test(
  "Non-interactive commands still work",
  not main_module.is_interactive_command({ "status" }),
  "status should not be interactive"
)

-- Test 4: Command aliases
runner.assert_test(
  "Desc alias detected as interactive",
  main_module.is_interactive_command({ "desc" }),
  "desc (alias for describe) should be detected as interactive"
)

runner.finish()
