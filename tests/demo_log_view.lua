#!/usr/bin/env -S nvim --headless -l

-- Demo script to show log view functionality
vim.cmd("set rtp+=.")
vim.cmd("runtime plugin/jj-fugitive.lua")

print("📜 === Enhanced Log View Demo ===")

-- Load the log module
local log_module = require("jj-fugitive.log")

-- Show log view with limited commits
log_module.show_log({ limit = 10 })

-- Get the current buffer (should be the log buffer)
local bufnr = vim.api.nvim_get_current_buf()
local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

print("\n✨ Enhanced log content preview:")
print(
  "──────────────────────────────────"
)
for i, line in ipairs(lines) do
  if i <= 20 then -- Show first 20 lines
    print(string.format("%2d: %s", i, line))
  else
    print("... (truncated)")
    break
  end
end
print(
  "──────────────────────────────────"
)

print("\n🎯 Log view features:")
print("  📜 Header with repository history info")
print("  🔍 Navigation instructions")
print("  📋 Column headers for better organization")
print("  👉 Special icon for current working copy (@)")
print("  🔀 Different icons for different commit types")
print("  🌱 Initial commits highlighted in green")
print("  🔧 Fix commits marked with repair icon")
print("  ➕ Add commits marked with plus icon")
print("  ➖ Remove commits marked with minus icon")
print("  💡 Clear command reference at bottom")

print("\n⌨️  Available keybindings:")
print("  Enter/o = Show commit details")
print("  e = Edit at commit (jj edit)")
print("  n = New commit after this one (jj new)")
print("  r = Rebase current commit onto this one (jj rebase)")
print("  d = Show diff for commit")
print("  q = Close log view")
print("  R = Refresh log")
print("  ? = Show detailed help")

print("\n🎉 Enhanced log view demonstration complete!")
