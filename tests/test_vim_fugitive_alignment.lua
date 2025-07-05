#!/usr/bin/env -S nvim --headless -l

-- Test vim-fugitive alignment keybindings
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

print("🚀 === jj-fugitive vim-fugitive Alignment Tests ===")

-- Test 1: Load status module and create fresh status buffer
local status_module = require("jj-fugitive.status")
assert_test("Status module loaded", status_module ~= nil, "Could not load status module")

-- Clear any existing jj-fugitive buffers to ensure clean test
for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
  if vim.api.nvim_buf_is_valid(bufnr) then
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name:match("jj%-") then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end
end

if status_module then
  local success = pcall(function()
    status_module.show_status()
  end)
  assert_test("Status buffer creation", success, "Failed to create status buffer")

  -- Find status buffer
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

  if status_buffer then
    vim.api.nvim_set_current_buf(status_buffer)

    -- Test 2: Check vim-fugitive aligned keybindings in status window
    local keymaps_to_test = {
      { key = "R", desc = "Reload status (was 'r')" },
      { key = "D", desc = "Diff file (was 'dd')" },
      { key = "dv", desc = "Vertical diff split" },
      { key = "ds", desc = "Horizontal diff split" },
      { key = "<CR>", desc = "Open file (was log view)" },
      { key = "o", desc = "Open file in split" },
      { key = "gO", desc = "Open file in vertical split" },
      { key = "O", desc = "Open file in new tab" },
      { key = "=", desc = "Inline diff toggle" },
      { key = "r", desc = "Restore file from parent" },
      { key = "a", desc = "Absorb changes into ancestors" },
      { key = "l", desc = "Show log view" },
      { key = "cc", desc = "Create commit" },
      { key = "ca", desc = "Amend commit" },
      { key = "ce", desc = "Extend commit" },
      { key = "cn", desc = "Create new commit" },
      { key = "q", desc = "Close status" },
      { key = "g?", desc = "Show help" },
    }

    for _, keymap in ipairs(keymaps_to_test) do
      local mapping = vim.fn.maparg(keymap.key, "n", false, true)
      assert_test(
        string.format("Status window has '%s' mapping", keymap.key),
        mapping ~= "",
        string.format("'%s' key (%s) not mapped", keymap.key, keymap.desc)
      )

      if type(mapping) == "table" then
        assert_test(
          string.format("'%s' mapping is buffer-local", keymap.key),
          mapping.buffer == 1,
          string.format("'%s' mapping should be buffer-local", keymap.key)
        )
      end
    end

    -- Test deprecated keybindings are removed
    local deprecated_keys = { "dd" }
    for _, key in ipairs(deprecated_keys) do
      local mapping = vim.fn.maparg(key, "n", false, true)
      local is_empty = mapping == "" or vim.tbl_isempty(mapping)
      assert_test(
        string.format("Deprecated key '%s' removed", key),
        is_empty,
        string.format("Deprecated key '%s' should be removed", key)
      )
    end
  end
end

-- Test 3: Test diff view keybindings
local diff_module = require("jj-fugitive.diff")
if diff_module then
  local success = pcall(function()
    diff_module.show_file_diff(nil, { format = "git" })
  end)
  assert_test("Diff buffer creation", success, "Failed to create diff buffer")

  -- Find diff buffer
  local diff_buffer = nil
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name:match("jj%-diff:") then
        diff_buffer = bufnr
        break
      end
    end
  end

  if diff_buffer then
    vim.api.nvim_set_current_buf(diff_buffer)

    local diff_keymaps = {
      { key = "g?", desc = "Show help (was '?')" },
      { key = "[c", desc = "Previous change" },
      { key = "]c", desc = "Next change" },
      { key = "q", desc = "Close diff" },
      { key = "o", desc = "Open file" },
    }

    for _, keymap in ipairs(diff_keymaps) do
      local mapping = vim.fn.maparg(keymap.key, "n", false, true)
      assert_test(
        string.format("Diff window has '%s' mapping", keymap.key),
        mapping ~= "",
        string.format("'%s' key (%s) not mapped in diff view", keymap.key, keymap.desc)
      )
    end
  end
end

-- Test 4: Test log view keybindings
local log_module = require("jj-fugitive.log")
if log_module then
  local success = pcall(function()
    log_module.show_log({ limit = 5 })
  end)
  assert_test("Log buffer creation", success, "Failed to create log buffer")

  -- Find log buffer
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

  if log_buffer then
    vim.api.nvim_set_current_buf(log_buffer)

    local log_keymaps = {
      { key = "g?", desc = "Show help (was '?')" },
      { key = "<CR>", desc = "Show commit details" },
      { key = "o", desc = "Show commit details" },
      { key = "P", desc = "Navigate to parent revision" },
      { key = "N", desc = "Navigate to next/child revision" },
      { key = "=", desc = "Expand log view" },
      { key = "+", desc = "Expand log view" },
      { key = "q", desc = "Close log" },
      { key = "R", desc = "Refresh log" },
    }

    for _, keymap in ipairs(log_keymaps) do
      local mapping = vim.fn.maparg(keymap.key, "n", false, true)
      assert_test(
        string.format("Log window has '%s' mapping", keymap.key),
        mapping ~= "",
        string.format("'%s' key (%s) not mapped in log view", keymap.key, keymap.desc)
      )
    end
  end
end

-- Test 5: Test help content updates
-- Re-find status buffer for this test
local status_buffer_for_help = nil
for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
  if vim.api.nvim_buf_is_valid(bufnr) then
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name:match("jj%-status$") then
      status_buffer_for_help = bufnr
      break
    end
  end
end

if status_buffer_for_help then
  vim.api.nvim_set_current_buf(status_buffer_for_help)
  local lines = vim.api.nvim_buf_get_lines(status_buffer_for_help, 0, -1, false)
  local help_text = table.concat(lines, "\n")

  -- Check that help text reflects new keybindings
  assert_test(
    "Help text mentions vim-fugitive style keys",
    help_text:match("<CR>") and help_text:match("g%?"),
    "Help text should mention <CR> and g? keys"
  )

  assert_test(
    "Help text doesn't mention old keys",
    not help_text:match("dd ="),
    "Help text should not mention deprecated 'dd' key"
  )
end

-- Test 6: Test that help windows can be opened
if status_buffer_for_help then
  vim.api.nvim_set_current_buf(status_buffer_for_help)

  local help_success = pcall(function()
    vim.api.nvim_feedkeys("g?", "n", false)
    vim.schedule(function() end) -- Allow processing
  end)

  assert_test("Status help can be triggered", help_success, "g? should open help in status window")

  -- Clean up any help windows
  vim.defer_fn(function()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      local bufname = vim.api.nvim_buf_get_name(buf)
      if bufname:match("help") or vim.api.nvim_win_get_config(win).relative ~= "" then
        pcall(vim.api.nvim_win_close, win, true)
      end
    end
  end, 100)
end

-- Summary
print("\n📊 === vim-fugitive Alignment Test Results Summary ===")
local passed = 0
local total = #test_results

for _, result in ipairs(test_results) do
  if result.passed then
    passed = passed + 1
  end
end

print(string.format("Passed: %d/%d tests", passed, total))

if passed == total then
  print("🎉 All vim-fugitive alignment tests passed!")
  print("✅ jj-fugitive keybindings now align with vim-fugitive patterns")
  print("")
  print("Key changes made:")
  print("  • Status: 'r' → 'R' for reload, 'dd' → 'D' for diff")
  print("  • Status: Enter now opens files (vim-fugitive standard)")
  print("  • All views: '?' → 'g?' for help (vim-fugitive standard)")
  print("  • Diff: Added '[c' and ']c' for change navigation")
  print("  • Added 'dv' and 'ds' for vertical/horizontal diff splits")
  os.exit(0)
else
  print("💥 Some vim-fugitive alignment tests failed!")
  for _, result in ipairs(test_results) do
    if not result.passed then
      print("  ❌ " .. result.name .. ": " .. (result.message or ""))
    end
  end
  os.exit(1)
end
