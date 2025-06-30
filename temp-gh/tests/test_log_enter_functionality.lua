#!/usr/bin/env -S nvim --headless -l

-- Test log view Enter functionality specifically
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

print("🚀 === jj-fugitive Log Enter Functionality Tests ===")

-- Test 1: Load required modules
local log_module = nil
local main_module = nil
pcall(function()
  log_module = require("jj-fugitive.log")
  main_module = require("jj-fugitive.init")
end)
assert_test(
  "Module loading",
  log_module ~= nil and main_module ~= nil,
  "Could not load required modules"
)

if log_module and main_module then
  -- Test 2: Create log view
  local initial_buf_count = #vim.api.nvim_list_bufs()
  pcall(function()
    log_module.show_log({ limit = 5 })
  end)

  local final_buf_count = #vim.api.nvim_list_bufs()
  assert_test(
    "Log buffer creation",
    final_buf_count > initial_buf_count,
    "Log buffer was not created"
  )

  -- Test 3: Find and verify log buffer
  local log_buffer = nil
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name:match("jj%-log") then
        log_buffer = bufnr
        break
      end
    end
  end

  assert_test("Log buffer found", log_buffer ~= nil, "Could not find log buffer by name")

  if log_buffer then
    vim.api.nvim_set_current_buf(log_buffer)
    local lines = vim.api.nvim_buf_get_lines(log_buffer, 0, -1, false)
    assert_test("Log buffer has content", #lines > 0, "Log buffer is empty")

    -- Test 4: Verify log buffer format
    local has_header = false
    local has_commits = false
    local commit_lines = {}

    for i, line in ipairs(lines) do
      if line:match("# jj Log View") then
        has_header = true
      end

      -- Check for native jj commit lines (with @ ◆ ○ symbols)
      if
        not line:match("^#")
        and line ~= ""
        and (line:match("@") or line:match("◆") or line:match("○"))
      then
        -- Extract 8-character hex commit ID from end of line
        local commit_id =
          line:match("([a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9])$")
        if commit_id then
          has_commits = true
          table.insert(commit_lines, { line_num = i, line = line, commit_id = commit_id })
        end
      end
    end

    assert_test("Log buffer has proper header", has_header, "Log buffer missing expected header")
    assert_test("Log buffer has commit lines", has_commits, "Log buffer has no valid commit lines")

    -- Test 5: Test cursor positioning
    if has_commits then
      local cursor_pos = vim.api.nvim_win_get_cursor(0)
      local current_line = vim.api.nvim_get_current_line()

      -- Check if cursor is positioned on a valid commit line
      local cursor_on_commit = false
      for _, commit_info in ipairs(commit_lines) do
        if cursor_pos[1] == commit_info.line_num then
          cursor_on_commit = true
          break
        end
      end

      assert_test(
        "Cursor positioned on commit line",
        cursor_on_commit,
        "Cursor not positioned on a valid commit line"
      )

      -- Test 6: Test commit ID extraction function
      local function get_commit_from_line(line)
        local first_part = line:match("^([^|]+)")
        if first_part then
          first_part = vim.trim(first_part)
          if not (first_part:match("Commit ID") or first_part:match("Description")) then
            local tokens = {}
            for token in first_part:gmatch("%S+") do
              table.insert(tokens, token)
            end
            if #tokens >= 3 then
              return tokens[#tokens]
            end
          end
        end
        return nil
      end

      local extracted_commit_id = get_commit_from_line(current_line)
      assert_test(
        "Commit ID extraction from cursor line",
        extracted_commit_id ~= nil,
        "Could not extract commit ID from cursor line: " .. current_line
      )

      -- Test 7: Test jj show command (simulating Enter press)
      if extracted_commit_id then
        print("Testing with commit ID:", extracted_commit_id)
        local show_result = main_module.run_jj_command_from_module({ "show", extracted_commit_id })
        assert_test(
          "jj show command for extracted commit ID",
          show_result ~= nil,
          "jj show failed for commit ID: " .. extracted_commit_id
        )

        if show_result then
          local has_commit_details = show_result:match("Commit ID:")
            or show_result:match("Change ID:")
          assert_test(
            "jj show returns valid commit details",
            has_commit_details,
            "jj show output doesn't contain expected commit details"
          )
        end
      end

      -- Test 8: Test Enter functionality from subdirectory
      print("\n=== Testing Enter functionality from subdirectory ===")
      local original_cwd = vim.fn.getcwd()
      vim.cmd("cd lua")

      if extracted_commit_id then
        local subdir_show_result =
          main_module.run_jj_command_from_module({ "show", extracted_commit_id })
        assert_test(
          "jj show from subdirectory",
          subdir_show_result ~= nil,
          "jj show failed from subdirectory"
        )
      end

      vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))

      -- Test 9: Test multiple commit lines
      local valid_commits = 0
      for _, commit_info in ipairs(commit_lines) do
        local test_result =
          main_module.run_jj_command_from_module({ "show", commit_info.commit_id })
        if test_result then
          valid_commits = valid_commits + 1
        end
      end

      assert_test(
        "Multiple commit IDs are valid",
        valid_commits > 0,
        "No valid commit IDs found in log view"
      )

      print(
        string.format("Found %d valid commit lines out of %d total", valid_commits, #commit_lines)
      )
    end
  end
end

-- Summary
print("\n📊 === Log Enter Functionality Test Results Summary ===")
local passed = 0
local total = #test_results

for _, result in ipairs(test_results) do
  if result.passed then
    passed = passed + 1
  end
end

print(string.format("Passed: %d/%d tests", passed, total))

if passed == total then
  print("🎉 All log Enter functionality tests passed!")
  print("✅ Pressing Enter in log view should work correctly")
  os.exit(0)
else
  print("💥 Some log Enter functionality tests failed!")
  for _, result in ipairs(test_results) do
    if not result.passed then
      print("  ❌ " .. result.name .. ": " .. (result.message or ""))
    end
  end
  os.exit(1)
end
