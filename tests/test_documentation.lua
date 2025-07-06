#!/usr/bin/env -S nvim --headless -l

local runner = require("tests.test_runner")
runner.init("jj-fugitive Documentation Tests")

-- Test 1: Check if doc directory exists
local doc_dir = vim.fn.getcwd() .. "/doc"
local doc_exists = vim.fn.isdirectory(doc_dir) == 1
runner.assert_test(
  "doc/ directory exists",
  doc_exists,
  "doc/ directory should exist for vim help files"
)

-- Test 2: Check if help file exists
local help_file = doc_dir .. "/jj-fugitive.txt"
local help_exists = vim.fn.filereadable(help_file) == 1
runner.assert_test("jj-fugitive.txt help file exists", help_exists, "Help file should exist")

if help_exists then
  -- Test 3: Read and validate help file content
  local content = table.concat(vim.fn.readfile(help_file), "\n")

  -- Test basic vim help format
  runner.assert_test(
    "Help file has proper header",
    content:match("*jj%-fugitive%.txt*") and content:match("*jj%-fugitive*"),
    "Help file should have proper vim help tags"
  )

  -- Test sections exist
  local required_sections = {
    "INTRODUCTION",
    "COMMANDS",
    "STATUS BUFFER",
    "DIFF BUFFER",
    "LOG BUFFER",
    "COMPLETION",
    "CONFIGURATION",
    "INTEGRATION",
    "EXAMPLES",
    "TROUBLESHOOTING",
    "ABOUT",
  }

  for _, section in ipairs(required_sections) do
    runner.assert_test(
      string.format("Help file contains %s section", section),
      content:find(section, 1, true),
      string.format("Help file should contain %s section", section)
    )
  end

  -- Test command documentation
  local commands = { ":J" }
  for _, cmd in ipairs(commands) do
    runner.assert_test(
      string.format("Help file documents %s command", cmd),
      content:find(cmd, 1, true),
      string.format("Help file should document %s command", cmd)
    )
  end

  -- Test keybinding documentation
  local keybindings = { "<CR>", "D", "dv", "ds", "R", "g?", "[c", "]c" }
  for _, key in ipairs(keybindings) do
    runner.assert_test(
      string.format("Help file documents %s keybinding", key),
      content:find(key, 1, true),
      string.format("Help file should document %s keybinding", key)
    )
  end

  -- Test help tags for cross-references
  local help_tags = {
    "*jj-fugitive-status*",
    "*jj-fugitive-diff*",
    "*jj-fugitive-log*",
    "*jj-fugitive-completion*",
  }

  for _, tag in ipairs(help_tags) do
    runner.assert_test(
      string.format("Help file has %s tag", tag),
      content:find(vim.pesc(tag), 1, false),
      string.format("Help file should have %s tag for cross-references", tag)
    )
  end

  -- Test vim help file format (ends with vim modeline)
  runner.assert_test(
    "Help file has vim modeline",
    content:match("vim:.*ft=help"),
    "Help file should end with vim modeline for proper formatting"
  )

  -- Test file structure
  local lines = vim.split(content, "\n")
  local line_count = #lines

  runner.assert_test(
    "Help file has substantial content",
    line_count > 50,
    "Help file should have substantial documentation content"
  )

  -- Test for proper vim help tags (surrounded by asterisks)
  local tag_count = 0
  for line in content:gmatch("[^\n]*") do
    local tags_in_line = {}
    for tag in line:gmatch("%*[^%*]+%*") do
      tag_count = tag_count + 1
      table.insert(tags_in_line, tag)
    end
  end

  runner.assert_test(
    "Help file has sufficient help tags",
    tag_count >= 10,
    string.format("Help file should have at least 10 help tags, found %d", tag_count)
  )
end

-- Test 4: Test integration with vim help system (if possible in headless mode)
if help_exists then
  local success = pcall(function()
    vim.cmd("helptags " .. doc_dir)
  end)

  runner.assert_test(
    "Help tags can be generated",
    success,
    "vim should be able to generate help tags from the help file"
  )

  -- Check if tags file was created
  local tags_file = doc_dir .. "/tags"
  local tags_exists = vim.fn.filereadable(tags_file) == 1
  runner.assert_test(
    "Help tags file created",
    tags_exists,
    "tags file should be created by helptags"
  )
end

runner.finish({
  "🎉 All documentation tests passed!",
  "✅ Vim-style help documentation created successfully",
  "",
  "Documentation features:",
  "  • Complete vim help file in doc/jj-fugitive.txt",
  "  • Proper vim help tags and cross-references",
  "  • Comprehensive command and keybinding documentation",
  "  • Examples and troubleshooting sections",
  "  • Integration with vim's help system",
  "",
  "Users can now access help with:",
  "  :help jj-fugitive",
  "  :help jj-fugitive-status",
  "  :help :J",
})
