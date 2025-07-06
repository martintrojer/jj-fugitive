#!/usr/bin/env -S nvim --headless -l

local runner = require("tests.test_runner")

runner.init("Multi-Level Completion Tests")

local completion_module = runner.load_module("jj-fugitive.completion")

-- Test 1: Basic completion functionality
runner.check_function(completion_module, "complete_jj_command", "Completion module")

-- Test 2: Multi-level completion
if completion_module then
  local basic_completions = completion_module.complete_jj_command("", "J ", 2)
  runner.assert_test(
    "Basic command completion works",
    basic_completions and #basic_completions > 0,
    "Should return command completions"
  )

  -- Test git subcommand completion
  local git_completions = completion_module.complete_jj_command("git ", "J git ", 6)
  runner.assert_test(
    "Git subcommand completion works",
    git_completions and #git_completions > 0,
    "Should return git subcommand completions"
  )

  -- Test bookmark subcommand completion
  local bookmark_completions = completion_module.complete_jj_command("bookmark ", "J bookmark ", 10)
  runner.assert_test(
    "Bookmark subcommand completion works",
    bookmark_completions and #bookmark_completions > 0,
    "Should return bookmark subcommand completions"
  )
end

-- Test 3: Completion accuracy
if completion_module then
  local status_completions = completion_module.complete_jj_command("st", "J st", 4)
  local has_status = false
  if status_completions then
    for _, comp in ipairs(status_completions) do
      if comp:match("status") then
        has_status = true
        break
      end
    end
  end

  runner.assert_test(
    "Partial command completion works",
    has_status,
    "Should complete partial commands like 'st' to 'status'"
  )
end

runner.finish()
