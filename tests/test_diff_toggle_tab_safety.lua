#!/usr/bin/env -S nvim --headless -l

local runner = require("tests.test_runner")

runner.init("Diff Toggle Tab Safety Tests")

local diff = runner.load_module("jj-fugitive.diff")

-- Prepare a file with changes
local fname = "toggle_safety.txt"
runner.create_test_file(fname, "one\n")
vim.fn.system({ "jj", "file", "track", fname })
local f = io.open(fname, "w")
if f then
  f:write("one\ntwo\n")
  f:close()
end

-- Open an unrelated tab
vim.cmd("tabnew")
local unrelated_tabs = vim.fn.tabpagenr("$")
runner.assert_test("Opened unrelated tab", unrelated_tabs >= 2, "Should have at least 2 tabs now")

-- Show unified diff with parentheses in name (color-words)
diff.show_file_diff(fname, { color_words = true })
local tabs_before_toggle = vim.fn.tabpagenr("$")

-- Toggle to side-by-side: should create a new tab and set marker
local ok1 = pcall(function()
  diff.toggle_diff_view(fname)
end)
runner.assert_test("Toggle to side-by-side ok", ok1, "toggle to sbs should not error")
local tabs_after_sbs = vim.fn.tabpagenr("$")
runner.assert_test(
  "Side-by-side opened new tab",
  tabs_after_sbs == tabs_before_toggle + 1,
  "Should add exactly one tab"
)
runner.assert_test("SBS marker set", vim.t.jj_sbs_diff ~= nil, "Should set jj_sbs_diff tab marker")

-- Toggle back to unified: should close one tab and clear marker
local ok2 = pcall(function()
  diff.toggle_diff_view(fname)
end)
runner.assert_test("Toggle back to unified ok", ok2, "toggle back should not error")
local tabs_after_unified = vim.fn.tabpagenr("$")
runner.assert_test(
  "Unified closed sbs tab",
  tabs_after_unified == tabs_before_toggle,
  "Should be back to initial tab count for diff"
)
runner.assert_test("SBS marker cleared", vim.t.jj_sbs_diff == nil, "Should clear jj_sbs_diff tab marker")

-- Ensure unrelated tab still exists (tab count at least initial unrelated count)
local final_tabs = vim.fn.tabpagenr("$")
runner.assert_test(
  "Unrelated tab preserved",
  final_tabs >= unrelated_tabs,
  "Unrelated tabs should not be closed by toggle"
)

-- Cleanup file
pcall(function()
  os.remove(fname)
end)

runner.finish()

