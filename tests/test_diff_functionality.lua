#!/usr/bin/env -S nvim --headless -l

-- Test diff functionality
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

print("🚀 === jj-fugitive Diff Functionality Tests ===")

-- Test 1: Check if diff module can be loaded
local diff_module = nil
pcall(function()
  diff_module = require("jj-fugitive.diff")
end)
assert_test("Diff module loading", diff_module ~= nil, "Could not require jj-fugitive.diff")

-- Test 2: Check if JDiff command exists
local jdiff_exists = vim.fn.exists(":JDiff") == 1
assert_test("JDiff command exists", jdiff_exists, ":JDiff command not found")

-- Test 3: Create test file with changes
local test_file = "test_diff_functionality.txt"
local file = io.open(test_file, "w")
if file then
  file:write("Line 1\nLine 2\nLine 3\n")
  file:close()
end

-- Track the file in jj
vim.fn.system({ "jj", "file", "track", test_file })

-- Modify the file
file = io.open(test_file, "w")
if file then
  file:write("Line 1 modified\nLine 2\nLine 3\nLine 4 added\n")
  file:close()
end

assert_test(
  "Test file created and modified",
  vim.fn.filereadable(test_file) == 1,
  "Could not create test file"
)

-- Test 4: Check if jj diff works for the file
local jj_diff_result = vim.fn.system({ "jj", "diff", "--color", "never", test_file })
local jj_diff_works = vim.v.shell_error == 0 and string.len(jj_diff_result) > 0
assert_test("jj diff command works", jj_diff_works, "jj diff failed or returned empty")

if jj_diff_works then
  print("   Diff output length: " .. string.len(jj_diff_result))
end

-- Test 5: Test diff viewer function
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
      local has_diff_content = string.len(content) > 0
        and (content:match("diff") or content:match("@@") or content:match("Added regular file"))

      assert_test(
        "Diff buffer has content",
        has_diff_content,
        "Diff buffer appears empty or invalid"
      )

      if has_diff_content then
        print("   Diff buffer content length: " .. string.len(content))
        print("   First 100 chars: " .. string.sub(content, 1, 100))
      end

      -- Test buffer options
      local buftype = vim.api.nvim_buf_get_option(diff_buffer, "buftype")
      local filetype = vim.api.nvim_buf_get_option(diff_buffer, "filetype")
      local modifiable = vim.api.nvim_buf_get_option(diff_buffer, "modifiable")

      assert_test(
        "Diff buffer has correct buftype",
        buftype == "nofile",
        "buftype is " .. buftype .. ", expected nofile"
      )
      assert_test(
        "Diff buffer has diff filetype",
        filetype == "diff",
        "filetype is " .. filetype .. ", expected diff"
      )
      assert_test(
        "Diff buffer is not modifiable",
        modifiable == false,
        "buffer should not be modifiable"
      )
    end
  end
end

-- Test 6: Test :JDiff command
if jdiff_exists then
  local initial_buf_count = #vim.api.nvim_list_bufs()

  pcall(function()
    vim.cmd("JDiff " .. test_file)
  end)

  local final_buf_count = #vim.api.nvim_list_bufs()
  local jdiff_created_buffer = final_buf_count > initial_buf_count

  assert_test(
    "JDiff command creates buffer",
    jdiff_created_buffer,
    ":JDiff did not create new buffer"
  )
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
