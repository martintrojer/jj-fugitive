#!/usr/bin/env -S nvim --headless -l

local runner = require("tests.test_runner")

runner.init("jj-fugitive Status Keybinding Tests")

local status_module = runner.load_module("jj-fugitive.status")

-- Test 1: Create status buffer to test keybindings
if status_module then
  local success = pcall(function()
    status_module.show_status()
  end)
  runner.assert_test("Status buffer creation", success, "show_status should work")
end

local status_bufnr = runner.find_buffer("jj%-status")
runner.assert_test("Status buffer found", status_bufnr ~= nil, "Status buffer should exist")

-- Test 2: Essential keybindings
if status_bufnr then
  local keymaps = vim.api.nvim_buf_get_keymap(status_bufnr, "n")
  local key_found = {}

  local essential_keys = { "<CR>", "q", "R", "d", "D", "l", "cc", "ca" }
  for _, keymap in ipairs(keymaps) do
    for _, key in ipairs(essential_keys) do
      if keymap.lhs == key then
        key_found[key] = true
      end
    end
  end

  for _, key in ipairs(essential_keys) do
    runner.assert_test(
      "Key '" .. key .. "' mapped",
      key_found[key] == true,
      "Essential key " .. key .. " should be mapped"
    )
  end
end

-- Test 3: Help keybinding
if status_bufnr then
  local help_mapping = vim.fn.maparg("g?", "n", false, true)
  runner.assert_test(
    "Help keybinding exists",
    help_mapping and help_mapping.buffer == 1,
    "g? should show help"
  )
end

runner.finish()
