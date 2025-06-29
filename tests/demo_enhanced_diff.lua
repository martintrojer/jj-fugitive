#!/usr/bin/env -S nvim --headless -l

-- Enhanced diff view demonstration script
-- This script demonstrates the improved UX features of the jj-fugitive diff viewer
vim.cmd("set rtp+=.")
vim.cmd("runtime plugin/jj-fugitive.lua")

local test_results = {}
local function assert_demo(name, condition, message)
  if condition then
    print("✅ DEMO: " .. name)
    table.insert(test_results, { name = name, passed = true })
  else
    print("❌ DEMO: " .. name .. " - " .. (message or ""))
    table.insert(test_results, { name = name, passed = false, message = message })
  end
end

print("🎨 === Enhanced Diff View Demo ===")

-- Load the diff module
local diff_module = require("jj-fugitive.diff")

-- Show enhanced diff for our test file
diff_module.show_file_diff("tests/test_enhanced_diff.txt")

-- Get the current buffer (should be the diff buffer)
local bufnr = vim.api.nvim_get_current_buf()
local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
local content = table.concat(lines, "\n")

assert_demo("Enhanced diff buffer created", bufnr ~= nil, "No diff buffer created")
assert_demo("File header with emoji present", content:match("📄 File:"), "File header not found")
assert_demo(
  "Change description present",
  content:match("🔄 Changes in working copy"),
  "Change description not found"
)
assert_demo("Visual separator present", content:match("─+"), "Visual separator not found")

print("\n✨ Enhanced diff content preview:")
print(
  "──────────────────────────────────"
)
for i, line in ipairs(lines) do
  if i <= 15 then -- Show first 15 lines
    print(string.format("%2d: %s", i, line))
  else
    print("... (truncated)")
    break
  end
end
print(
  "──────────────────────────────────"
)

print("\n🎯 Enhancement features applied:")
print("  📄 File headers with emoji icons for clarity")
print("  🔄 Clear change descriptions")
print("  📁 Enhanced git diff headers")
print("  📍 Prominent hunk location markers")
print("  ❌ Red highlighted removed lines with icons")
print("  ✅ Green highlighted added lines with icons")
print("  ➡️ ⬅️ File markers for old/new versions")
print("  🔗 Index information styling")
print("  📏 Visual separators for better organization")
print("  🎨 Custom color scheme for improved readability")

-- Summary
print("\n📊 === Demo Results Summary ===")
local passed = 0
local total = #test_results

for _, result in ipairs(test_results) do
  if result.passed then
    passed = passed + 1
  end
end

print(string.format("Demo checks passed: %d/%d", passed, total))

if passed == total then
  print("🎉 Enhanced diff view demonstration complete!")
  os.exit(0)
else
  print("💥 Some demo checks failed!")
  for _, result in ipairs(test_results) do
    if not result.passed then
      print("  ❌ " .. result.name .. ": " .. (result.message or ""))
    end
  end
  os.exit(1)
end
