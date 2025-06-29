#!/usr/bin/env -S nvim --headless -l

-- Test color rendering functionality
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

print("🎨 === jj-fugitive Color Rendering Tests ===")

-- Test 1: Check if diff module can be loaded
local diff_module = nil
pcall(function()
  diff_module = require("jj-fugitive.diff")
end)
assert_test("Diff module loading", diff_module ~= nil, "Could not require jj-fugitive.diff")

-- Create test file with changes to generate colored diff
local test_file = "test_color_rendering.txt"
local file = io.open(test_file, "w")
if file then
  file:write("Line 1\nLine 2\nLine 3\n")
  file:close()
end

-- Track the file in jj
vim.fn.system({ "jj", "file", "track", test_file })

-- Modify the file to create additions and deletions
file = io.open(test_file, "w")
if file then
  file:write("Line 1 modified\nLine 2\nLine 4 added\n")
  file:close()
end

-- Test 2: Get colored diff output
local jj_diff_colored = vim.fn.system({ "jj", "diff", "--color", "always", test_file })
local has_ansi_codes = jj_diff_colored:match("\27%[[0-9;]*m")
assert_test(
  "jj diff produces ANSI color codes",
  has_ansi_codes ~= nil,
  "No ANSI escape sequences found"
)

if has_ansi_codes then
  print("   Found ANSI codes in diff output")
end

-- Test 3: Create diff buffer and verify ANSI codes are removed
if diff_module then
  local initial_buf_count = #vim.api.nvim_list_bufs()

  pcall(function()
    diff_module.show_file_diff(test_file)
  end)

  local final_buf_count = #vim.api.nvim_list_bufs()
  local diff_buffer_created = final_buf_count > initial_buf_count

  assert_test("Diff buffer created", diff_buffer_created, "No new buffer created by show_file_diff")

  if diff_buffer_created then
    -- Find the diff buffer
    local diff_buffer = nil
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        local name = vim.api.nvim_buf_get_name(bufnr)
        if name:match("jj%-diff") and name:match(test_file) then
          diff_buffer = bufnr
          break
        end
      end
    end

    assert_test("Diff buffer found", diff_buffer ~= nil, "Could not find diff buffer by name")

    if diff_buffer then
      local lines = vim.api.nvim_buf_get_lines(diff_buffer, 0, -1, false)
      local content = table.concat(lines, "\n")

      -- Test 4: Verify ANSI codes are stripped from buffer content
      local has_ansi_in_buffer = content:match("\27%[[0-9;]*m")
      assert_test(
        "ANSI codes stripped from buffer",
        has_ansi_in_buffer == nil,
        "ANSI codes still present in buffer text"
      )

      -- Test 5: Verify buffer has diff content
      local has_diff_content = content:match("diff --git")
        or content:match("@@")
        or content:match("Added regular file")
      assert_test("Buffer has diff content", has_diff_content, "No diff markers found in buffer")

      -- Test 6: Check for highlight groups in buffer
      -- Get all highlights in the buffer - use namespace -1 to get all namespaces
      local highlights = {}
      local line_count = vim.api.nvim_buf_line_count(diff_buffer)

      for line = 0, math.min(line_count - 1, 10) do -- Check first 10 lines to avoid too much output
        local line_highlights = vim.api.nvim_buf_get_extmarks(
          diff_buffer,
          -1, -- all namespaces
          { line, 0 },
          { line, -1 },
          { details = true }
        )
        for _, hl in ipairs(line_highlights) do
          if hl[4] and hl[4].hl_group then
            table.insert(highlights, hl[4].hl_group)
          end
        end
      end

      local has_color_highlights = #highlights > 0
      assert_test(
        "Buffer has color highlights",
        has_color_highlights,
        "No highlight groups found in buffer"
      )

      if has_color_highlights then
        print("   Found highlight groups: " .. table.concat(highlights, ", "))
      else
        print("   No highlight groups found - this might be expected in headless mode")
      end

      print("   Buffer content length: " .. string.len(content))
      print("   First 150 chars: " .. string.sub(content, 1, 150))
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
