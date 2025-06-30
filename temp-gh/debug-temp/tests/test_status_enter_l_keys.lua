#!/usr/bin/env -S nvim --headless -l

-- Test status window Enter and 'l' key functionality
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

print("🚀 === jj-fugitive Status Enter/'l' Key Tests ===")

-- Test 1: Load required modules
local status_module = nil
local log_module = nil
pcall(function()
  status_module = require("jj-fugitive.status")
  log_module = require("jj-fugitive.log")
end)
assert_test(
  "Module loading",
  status_module ~= nil and log_module ~= nil,
  "Could not load required modules"
)

if status_module and log_module then
  -- Test 2: Create status buffer
  local success = pcall(function()
    status_module.show_status()
  end)
  assert_test("Status buffer creation", success, "Failed to create status buffer")

  -- Test 3: Find status buffer
  local status_buffer = nil
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name:match("jj%-status$") then
        status_buffer = bufnr
        break
      end
    end
  end

  assert_test("Status buffer found", status_buffer ~= nil, "Could not find status buffer by name")

  if status_buffer then
    -- Switch to status buffer
    vim.api.nvim_set_current_buf(status_buffer)

    -- Test 4: Check if Enter key mapping exists
    local enter_mapping = vim.fn.maparg("<CR>", "n", false, true)
    assert_test(
      "Enter key mapping exists",
      enter_mapping ~= "",
      "Enter key mapping not found in status buffer"
    )

    -- Test 5: Check if 'l' key mapping exists
    local l_mapping = vim.fn.maparg("l", "n", false, true)
    assert_test(
      "'l' key mapping exists",
      l_mapping ~= "",
      "'l' key mapping not found in status buffer"
    )

    -- Test 6: Verify mappings are buffer-local
    if enter_mapping ~= "" then
      local enter_info = type(enter_mapping) == "table" and enter_mapping or {}
      assert_test(
        "Enter mapping is buffer-local",
        enter_info.buffer == 1,
        "Enter mapping is not buffer-local"
      )
    end

    if l_mapping ~= "" then
      local l_info = type(l_mapping) == "table" and l_mapping or {}
      assert_test(
        "'l' mapping is buffer-local",
        l_info.buffer == 1,
        "'l' mapping is not buffer-local"
      )
    end

    -- Test 7: Test Enter key functionality (simulate keypress)
    local initial_log_buffers = 0
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        local name = vim.api.nvim_buf_get_name(bufnr)
        if name:match("jj%-log") then
          initial_log_buffers = initial_log_buffers + 1
        end
      end
    end

    -- Simulate Enter key press
    local enter_success = pcall(function()
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "n", false)
      vim.schedule(function() end) -- Allow event processing
    end)

    assert_test("Enter key simulation", enter_success, "Failed to simulate Enter key press")

    -- Give some time for the log view to be created
    vim.defer_fn(function()
      local final_log_buffers = 0
      for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(bufnr) then
          local name = vim.api.nvim_buf_get_name(bufnr)
          if name:match("jj%-log") then
            final_log_buffers = final_log_buffers + 1
          end
        end
      end

      assert_test(
        "Log buffer created after Enter",
        final_log_buffers > initial_log_buffers,
        "Log buffer was not created after Enter key press"
      )

      -- Test 8: Test 'l' key functionality
      -- Switch back to status buffer
      vim.api.nvim_set_current_buf(status_buffer)

      local l_success = pcall(function()
        vim.api.nvim_feedkeys("l", "n", false)
        vim.schedule(function() end) -- Allow event processing
      end)

      assert_test("'l' key simulation", l_success, "Failed to simulate 'l' key press")

      -- Test 9: Verify both keys call the same function
      local enter_func = nil
      local l_func = nil

      if type(enter_mapping) == "table" and enter_mapping.callback then
        enter_func = tostring(enter_mapping.callback)
      elseif type(enter_mapping) == "table" and enter_mapping.rhs then
        enter_func = enter_mapping.rhs
      end

      if type(l_mapping) == "table" and l_mapping.callback then
        l_func = tostring(l_mapping.callback)
      elseif type(l_mapping) == "table" and l_mapping.rhs then
        l_func = l_mapping.rhs
      end

      assert_test(
        "Enter and 'l' keys have same functionality",
        enter_func == l_func,
        "Enter and 'l' keys do not call the same function"
      )

      -- Print summary
      print("\n📊 === Status Enter/'l' Key Test Results Summary ===")
      local passed = 0
      local total = #test_results

      for _, result in ipairs(test_results) do
        if result.passed then
          passed = passed + 1
        end
      end

      print(string.format("Passed: %d/%d tests", passed, total))

      if passed == total then
        print("🎉 All status Enter/'l' key tests passed!")
        print("✅ Enter and 'l' keys in status window work correctly")
        os.exit(0)
      else
        print("💥 Some status Enter/'l' key tests failed!")
        for _, result in ipairs(test_results) do
          if not result.passed then
            print("  ❌ " .. result.name .. ": " .. (result.message or ""))
          end
        end
        os.exit(1)
      end
    end, 100) -- 100ms delay to allow buffer creation
  end
end
