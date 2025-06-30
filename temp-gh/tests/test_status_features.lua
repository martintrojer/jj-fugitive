#!/usr/bin/env -S nvim --headless -l

-- Test status window advanced features: cursor positioning and buffer switching
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

print("🚀 === jj-fugitive Status Features Tests ===")

-- Test 1: Check if status module can be loaded
local status_module = nil
pcall(function()
  status_module = require("jj-fugitive.status")
end)
assert_test("Status module loading", status_module ~= nil, "Could not require jj-fugitive.status")

-- Test 2: Create test files with changes
local test_file1 = "status_test_file1.txt"
local test_file2 = "status_test_file2.txt"

-- Create and track first test file
local file = io.open(test_file1, "w")
if file then
  file:write("Original content 1\n")
  file:close()
end
vim.fn.system({ "jj", "file", "track", test_file1 })

-- Create and track second test file
file = io.open(test_file2, "w")
if file then
  file:write("Original content 2\n")
  file:close()
end
vim.fn.system({ "jj", "file", "track", test_file2 })

-- Modify both files to create changes
file = io.open(test_file1, "w")
if file then
  file:write("Modified content 1\nLine 2\n")
  file:close()
end

file = io.open(test_file2, "w")
if file then
  file:write("Modified content 2\nLine 2\n")
  file:close()
end

assert_test(
  "Test files created and modified",
  vim.fn.filereadable(test_file1) == 1 and vim.fn.filereadable(test_file2) == 1,
  "Could not create test files"
)

-- Test 3: Open status buffer and check cursor positioning
if status_module then
  -- Open status buffer
  status_module.show_status()

  -- Find the status buffer
  local status_buffer = nil
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name:match("jj%-status") then
        status_buffer = bufnr
        break
      end
    end
  end

  assert_test("Status buffer created", status_buffer ~= nil, "Could not find status buffer")

  if status_buffer then
    -- Check cursor position
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local cursor_line = cursor_pos[1]

    -- Get the line content at cursor position
    local lines = vim.api.nvim_buf_get_lines(status_buffer, 0, -1, false)
    local cursor_line_content = lines[cursor_line] or ""

    -- Check if cursor is positioned on a file line (starts with status character + space)
    local is_on_file_line = cursor_line_content:match("^[A-Z] ")

    assert_test(
      "Cursor positioned on first file",
      is_on_file_line ~= nil,
      "Cursor not positioned on a file line. Line: '" .. cursor_line_content .. "'"
    )

    if is_on_file_line then
      print("   Cursor at line " .. cursor_line .. ": " .. cursor_line_content)
    end
  end
end

-- Test 4: Buffer switching functionality
if status_module then
  -- First, open one of the test files in a buffer
  vim.cmd("edit " .. test_file1)
  local original_buf = vim.api.nvim_get_current_buf()
  local original_buf_name = vim.api.nvim_buf_get_name(original_buf)

  assert_test(
    "Test file opened in buffer",
    original_buf_name:match(test_file1) ~= nil,
    "Test file not properly opened"
  )

  -- Open status buffer again
  status_module.show_status()

  -- Find the status buffer
  local status_buffer = nil
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name:match("jj%-status") then
        status_buffer = bufnr
        break
      end
    end
  end

  if status_buffer then
    -- Find a line with our test file
    local lines = vim.api.nvim_buf_get_lines(status_buffer, 0, -1, false)
    local target_line = nil
    local target_filename = nil

    for i, line in ipairs(lines) do
      local filename = line:match("^[A-Z] (.+)")
      if filename and (filename == test_file1 or filename == test_file2) then
        target_line = i
        target_filename = filename
        break
      end
    end

    assert_test(
      "Found test file in status",
      target_line ~= nil,
      "Could not find test files in status buffer"
    )

    if target_line and target_filename then
      -- Set cursor to that line
      vim.api.nvim_win_set_cursor(0, { target_line, 0 })

      -- Test the buffer switching logic (simulate the "o" keymap)
      local line = vim.api.nvim_get_current_line()
      local filename = line:match("^[A-Z] (.+)")

      assert_test(
        "Filename extraction works",
        filename == target_filename,
        "Extracted filename '"
          .. (filename or "nil")
          .. "' doesn't match expected '"
          .. target_filename
          .. "'"
      )

      if filename then
        -- Test buffer detection logic
        local full_path = vim.fn.fnamemodify(filename, ":p")
        local existing_bufnr = nil

        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_valid(buf) then
            local buf_name = vim.api.nvim_buf_get_name(buf)
            if buf_name == full_path then
              existing_bufnr = buf
              break
            end
          end
        end

        if filename == test_file1 then
          -- This file should have an existing buffer
          assert_test(
            "Existing buffer detected for opened file",
            existing_bufnr ~= nil,
            "Should find existing buffer for " .. filename
          )

          assert_test(
            "Correct buffer detected",
            existing_bufnr == original_buf,
            "Detected buffer doesn't match original buffer"
          )
        else
          -- This file (test_file2) should not have an existing buffer
          assert_test(
            "No buffer detected for unopened file",
            existing_bufnr == nil,
            "Should not find existing buffer for " .. filename
          )
        end
      end
    end
  end
end

-- Test 5: Window switching logic
if status_module then
  -- Open test_file1 in a split window
  vim.cmd("split")
  vim.cmd("edit " .. test_file1)
  local file_buffer = vim.api.nvim_get_current_buf()

  -- Open status in another split (this will change the current window)
  vim.cmd("split")
  status_module.show_status()

  -- Test window detection logic - check if we can find the file buffer in any window
  local existing_win = nil
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == file_buffer then
      existing_win = win
      break
    end
  end

  assert_test(
    "Window detection finds file buffer",
    existing_win ~= nil,
    "Should find a window containing the file buffer"
  )

  -- Additional test: verify the window detection logic from our implementation
  if existing_win then
    local detected_buffer = vim.api.nvim_win_get_buf(existing_win)
    assert_test(
      "Detected window has correct buffer",
      detected_buffer == file_buffer,
      "Detected window should contain the file buffer"
    )
  end
end

-- Cleanup
pcall(function()
  os.remove(test_file1)
  os.remove(test_file2)
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
  print("🎉 All status features tests passed!")
  os.exit(0)
else
  print("💥 Some status features tests failed!")
  for _, result in ipairs(test_results) do
    if not result.passed then
      print("  ❌ " .. result.name .. ": " .. (result.message or ""))
    end
  end
  os.exit(1)
end
