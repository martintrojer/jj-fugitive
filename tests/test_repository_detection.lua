#!/usr/bin/env -S nvim --headless -l

local runner = require("tests.test_runner")
runner.init("jj-fugitive Repository Detection Tests")

runner.section("Module Loading")
-- Test 1: Load the main module
local main_module = runner.load_module("jj-fugitive.init")

if main_module then
  runner.section("Basic Repository Detection")
  -- Test 2: Test repository root detection from current directory
  local repo_root = main_module.get_repo_root()
  runner.assert_test(
    "Repository root detection",
    repo_root ~= nil,
    "Could not detect repository root"
  )

  if repo_root then
    runner.info("Repository root detected: " .. repo_root)
    runner.info("Current working directory: " .. vim.fn.getcwd())

    runner.section("Basic Command Execution")
    -- Test 3: Test running a simple jj command
    local result = main_module.run_jj_command_from_module({ "status" })
    runner.assert_test("jj status command execution", result ~= nil, "jj status command failed")

    -- Test 4: Test log command specifically
    local log_result = main_module.run_jj_command_from_module({ "log", "--limit", "2" })
    runner.assert_test("jj log command execution", log_result ~= nil, "jj log command failed")

    runner.section("Subdirectory Detection (Original Issue)")
    -- Test 5: Test from a subdirectory (the key issue that was reported)
    local original_cwd = vim.fn.getcwd()

    -- Change to lua subdirectory
    vim.cmd("cd lua")
    local sub_cwd = vim.fn.getcwd()
    runner.info("Changed to: " .. sub_cwd)

    local sub_repo_root = main_module.get_repo_root()
    runner.assert_test(
      "Repository root detection from subdirectory",
      sub_repo_root ~= nil,
      "Could not detect repository root from subdirectory"
    )

    if sub_repo_root then
      runner.assert_test(
        "Repository root consistency",
        sub_repo_root == repo_root,
        "Repository root differs when detected from subdirectory"
      )

      local sub_result = main_module.run_jj_command_from_module({ "status" })
      runner.assert_test(
        "jj status from subdirectory",
        sub_result ~= nil,
        "jj status failed from subdirectory"
      )

      local sub_log_result = main_module.run_jj_command_from_module({ "log", "--limit", "1" })
      runner.assert_test(
        "jj log from subdirectory",
        sub_log_result ~= nil,
        "jj log failed from subdirectory"
      )
    end

    -- Restore original directory
    vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))

    runner.section("Nested Subdirectory Detection")
    -- Test 6: Test from nested subdirectory
    if vim.fn.isdirectory("lua/jj-fugitive") == 1 then
      vim.cmd("cd lua/jj-fugitive")
      local nested_cwd = vim.fn.getcwd()
      runner.info("Changed to nested directory: " .. nested_cwd)

      local nested_repo_root = main_module.get_repo_root()
      runner.assert_test(
        "Repository root detection from nested subdirectory",
        nested_repo_root ~= nil,
        "Could not detect repository root from nested subdirectory"
      )

      if nested_repo_root then
        runner.assert_test(
          "Repository root consistency from nested directory",
          nested_repo_root == repo_root,
          "Repository root differs when detected from nested subdirectory"
        )

        local nested_result = main_module.run_jj_command_from_module({ "status" })
        runner.assert_test(
          "jj status from nested subdirectory",
          nested_result ~= nil,
          "jj status failed from nested subdirectory"
        )
      end

      -- Restore original directory
      vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))
    end
  end
end

runner.finish({
  "✅ The original issue with subdirectory execution should be fixed",
  "📝 Repository detection works from:",
  "   ✅ Project root directory",
  "   ✅ Direct subdirectories (lua/)",
  "   ✅ Nested subdirectories (lua/jj-fugitive/)",
  "   ✅ All jj commands execute correctly from any directory",
})
