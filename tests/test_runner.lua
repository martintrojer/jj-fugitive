-- Common test runner for jj-fugitive tests
-- Eliminates boilerplate and provides consistent test infrastructure

local M = {}

-- Test state
local test_results = {}
local test_count = 0
local passed_count = 0

-- Initialize test environment
function M.init(test_name)
  -- Set up Neovim environment
  vim.cmd("set rtp+=.")
  vim.cmd("runtime plugin/jj-fugitive.lua")

  -- Reset test state
  test_results = {}
  test_count = 0
  passed_count = 0

  print(string.format("🚀 === %s ===", test_name))
  return true
end

-- Assert a test condition
function M.assert_test(name, condition, message)
  test_count = test_count + 1

  if condition then
    print("✅ PASS: " .. name)
    passed_count = passed_count + 1
    table.insert(test_results, { name = name, passed = true })
  else
    print("❌ FAIL: " .. name .. " - " .. (message or ""))
    table.insert(test_results, { name = name, passed = false, message = message })
  end

  return condition
end

-- Print informational message
function M.info(message)
  print("  " .. message)
end

-- Skip a test with reason
function M.skip(name, reason)
  print("⏭️  SKIP: " .. name .. " - " .. (reason or ""))
  table.insert(test_results, { name = name, passed = true, skipped = true })
end

-- Start a test section
function M.section(name)
  print(string.format("\n🧪 %s", name))
end

-- Finish tests and exit with appropriate code
function M.finish(additional_summary)
  local failed_count = test_count - passed_count

  print(string.format("\n📊 === Test Results Summary ==="))
  print(string.format("Total tests run: %d", test_count))
  print(string.format("Passed: %d", passed_count))

  if failed_count > 0 then
    print(string.format("Failed: %d", failed_count))
    print("\n💥 Some tests failed!")
    for _, result in ipairs(test_results) do
      if not result.passed and not result.skipped then
        print("  ❌ " .. result.name .. ": " .. (result.message or ""))
      end
    end
    os.exit(1)
  else
    print(string.format("Failed: %d", failed_count))
    print("\n🎉 All tests passed!")

    if additional_summary then
      if type(additional_summary) == "table" then
        for _, line in ipairs(additional_summary) do
          print(line)
        end
      else
        print(additional_summary)
      end
    end

    os.exit(0)
  end
end

-- Utility: Load jj-fugitive module
function M.load_module(module_name)
  local ok, module = pcall(require, module_name)
  if not ok then
    M.assert_test(
      "Module " .. module_name .. " loading",
      false,
      "Failed to load module: " .. tostring(module)
    )
    return nil
  end
  M.assert_test("Module " .. module_name .. " loading", true)
  return module
end

-- Utility: Check if function exists on module
function M.check_function(module, func_name, module_name)
  module_name = module_name or "module"
  local has_func = module and type(module[func_name]) == "function"
  M.assert_test(
    string.format("%s has %s function", module_name, func_name),
    has_func,
    string.format("Function %s not found or not callable", func_name)
  )
  return has_func
end

-- Utility: Create test file
function M.create_test_file(filename, content)
  content = content or "Test file content\nLine 2\nLine 3"
  local file = io.open(filename, "w")
  if file then
    file:write(content)
    file:close()
    return M.assert_test("Test file " .. filename .. " created", true)
  else
    return M.assert_test("Test file " .. filename .. " created", false, "Failed to create file")
  end
end

-- Utility: Check if buffer exists with pattern
function M.find_buffer(pattern)
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name:match(pattern) then
        return bufnr
      end
    end
  end
  return nil
end

-- Utility: Count non-empty lines
function M.count_non_empty_lines(text)
  if not text then
    return 0
  end
  local count = 0
  for line in text:gmatch("[^\n]+") do
    if line:match("%S") then -- line contains non-whitespace
      count = count + 1
    end
  end
  return count
end

-- Utility: Check for ANSI codes
function M.has_ansi_codes(text)
  return text and text:match("\27%[[0-9;]*m") ~= nil
end

-- CI environment detection
function M.is_ci()
  return os.getenv("CI") ~= nil
end

return M
