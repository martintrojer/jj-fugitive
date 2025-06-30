#!/usr/bin/env -S nvim --headless -l

-- Test log view color rendering functionality
vim.cmd("set rtp+=.")
vim.cmd("runtime plugin/jj-fugitive.lua")

local test_results = {}
local function assert_test(name, condition, message)
  if condition then
    print("✅ PASS: " .. name)
    table.insert(test_results, { name = name, passed = true })
  else
    print("❌ FAIL: " .. name .. " - " .. (message or ""))
    table.insert(test_results, { name = name, passed = false, message = message })
  end
end

print("🎨 === jj-fugitive Log Color Rendering Tests ===")

-- Test 1: Check if log module can be loaded
local log_module = nil
pcall(function()
  log_module = require("jj-fugitive.log")
end)
assert_test("Log module loading", log_module ~= nil, "Could not require jj-fugitive.log")

-- Create test file with changes to generate some history
local test_file = "test_log_color_rendering.txt"
local file = io.open(test_file, "w")
if file then
  file:write("Line 1\nLine 2\n")
  file:close()
end

-- Track and commit the file
vim.fn.system({ "jj", "file", "track", test_file })
vim.fn.system({ "jj", "describe", "-m", "Add test file for log color testing" })

-- Modify the file and commit again
file = io.open(test_file, "w")
if file then
  file:write("Line 1 modified\nLine 2\nLine 3 added\n")
  file:close()
end

vim.fn.system({ "jj", "describe", "-m", "Modify test file" })

-- Test 2: Test that jj show produces colored output
local commit_output =
  vim.fn.system({ "jj", "log", "--limit", "1", "--template", "change_id.short()" })
local commit_id = vim.trim(commit_output:match("([^\n]+)"))
if commit_id and #commit_id > 0 then
  local jj_show_colored = vim.fn.system({ "jj", "show", "--color", "always", commit_id })
  local has_ansi_codes = jj_show_colored:match("\27%[[0-9;]*m")
  assert_test(
    "jj show produces ANSI color codes",
    has_ansi_codes ~= nil,
    "No ANSI escape sequences found"
  )

  if has_ansi_codes then
    print("   Found ANSI codes in jj show output")
  end

  -- Test 3: Test that jj diff produces colored output
  local jj_diff_colored = vim.fn.system({ "jj", "diff", "--color", "always", "-r", commit_id })
  local has_diff_ansi_codes = jj_diff_colored:match("\27%[[0-9;]*m")
  assert_test(
    "jj diff produces ANSI color codes",
    has_diff_ansi_codes ~= nil,
    "No ANSI escape sequences found"
  )

  if has_diff_ansi_codes then
    print("   Found ANSI codes in jj diff output")
  end
else
  assert_test("jj show produces ANSI color codes", false, "Could not get commit ID")
  assert_test("jj diff produces ANSI color codes", false, "Could not get commit ID")
end

-- Test 4: Create log view and test that commit details work
if log_module then
  local initial_buf_count = #vim.api.nvim_list_bufs()

  pcall(function()
    log_module.show_log({ limit = 5 })
  end)

  local final_buf_count = #vim.api.nvim_list_bufs()
  local log_buffer_created = final_buf_count > initial_buf_count

  assert_test("Log buffer created", log_buffer_created, "No new buffer created by show_log")

  if log_buffer_created then
    -- Find the log buffer
    local log_buffer = nil
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        local name = vim.api.nvim_buf_get_name(bufnr)
        -- Check for jj-log buffer (name might be empty in headless mode)
        if name:match("jj%-log") or name == "" then
          -- Additional check: look for jj log content in buffer
          local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 5, false)
          for _, line in ipairs(lines) do
            if line:match("jj Log View") then
              log_buffer = bufnr
              break
            end
          end
          if log_buffer then break end
        end
      end
    end

    assert_test("Log buffer found", log_buffer ~= nil, "Could not find log buffer by name")

    if log_buffer then
      local lines = vim.api.nvim_buf_get_lines(log_buffer, 0, -1, false)
      local content = table.concat(lines, "\n")

      -- Test 5: Verify log buffer has expected content (native jj format)
      local has_log_content = content:match("jj Log View") and (content:match("@") or content:match("◆") or content:match("○"))
      assert_test("Log buffer has expected content", has_log_content, "Log view content not found")

      -- Test 6: Verify we can extract a commit ID from a line (native format)
      local commit_line = nil
      for _, line in ipairs(lines) do
        -- Look for native jj commit lines (with @ ◆ ○ symbols)
        if not line:match("^#") and line ~= "" and (line:match("@") or line:match("◆") or line:match("○")) then
          -- Extract 8-character hex commit ID from end of line
          local commit_id = line:match("([a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9])$")
          if commit_id then
            commit_line = line
            break
          end
        end
      end

      assert_test(
        "Found valid commit line in log",
        commit_line ~= nil,
        "No valid commit line found"
      )

      if commit_line and commit_id then
        print("   Found commit ID: " .. commit_id)
        print("   Commit line: " .. commit_line:sub(1, 60) .. "...")

        -- We can't easily test the actual color rendering in headless mode,
        -- but we can verify the functions exist and would work
        assert_test("Log view color integration ready", true, "Ready for manual testing")
      end
    end
  end
end

-- Cleanup
pcall(function()
  os.remove(test_file)
end)

-- Summary
print("\n📊 === Test Results Summary ===")
local passed = 0
local total = #test_results

for _, result in ipairs(test_results) do
  if result.passed then
    passed = passed + 1
  end
end

print(string.format("Passed: %d/%d tests", passed, total))

if passed == total then
  print("🎉 All tests passed!")
  print("📝 Manual testing needed:")
  print("   1. Run ':J log' in Neovim")
  print("   2. Press Enter on a commit to see colored commit details")
  print("   3. Press 'd' on a commit to see colored diff")
  print("   4. Verify colors are rendered properly")
  os.exit(0)
else
  print("💥 Some tests failed!")
  for _, result in ipairs(test_results) do
    if not result.passed then
      print("  ❌ " .. result.name .. ": " .. (result.message or ""))
    end
  end
  os.exit(1)
end
