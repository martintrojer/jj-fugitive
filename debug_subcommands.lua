#!/usr/bin/env -S nvim --headless -l

vim.cmd("set rtp+=.")
vim.cmd("runtime plugin/jj-fugitive.lua")

-- Mock the parse_subcommands function to see what's happening
local completion_module = require("jj-fugitive.completion")

-- Test 1: Test git subcommand help parsing
print("=== Testing git subcommand help parsing ===")
local git_help = vim.fn.system({"jj", "git", "--help"})
print("Git help exit code:", vim.v.shell_error)
print("Git help output length:", #git_help)

-- Look for Commands section
local in_commands_section = false
local found_commands = {}
for line in git_help:gmatch("[^\r\n]+") do
  if line:match("^Commands:") then
    print("Found Commands section!")
    in_commands_section = true
  elseif line:match("^Options:") or line:match("^Usage:") then
    in_commands_section = false
  elseif in_commands_section then
    local subcmd = line:match("^%s+([a-z][a-z0-9%-]*)")
    if subcmd then
      table.insert(found_commands, subcmd)
      print("  Found subcommand:", subcmd)
    end
  end
end

print("Total git subcommands found:", #found_commands)
print("Git subcommands:", vim.inspect(found_commands))

-- Test 2: Test bookmark subcommand help parsing  
print("\n=== Testing bookmark subcommand help parsing ===")
local bookmark_help = vim.fn.system({"jj", "bookmark", "--help"})
print("Bookmark help exit code:", vim.v.shell_error)
print("Bookmark help output length:", #bookmark_help)

in_commands_section = false
found_commands = {}
for line in bookmark_help:gmatch("[^\r\n]+") do
  if line:match("^Commands:") then
    print("Found Commands section!")
    in_commands_section = true
  elseif line:match("^Options:") or line:match("^Usage:") then
    in_commands_section = false
  elseif in_commands_section then
    local subcmd = line:match("^%s+([a-z][a-z0-9%-]*)")
    if subcmd then
      table.insert(found_commands, subcmd)
      print("  Found subcommand:", subcmd)
    end
  end
end

print("Total bookmark subcommands found:", #found_commands)
print("Bookmark subcommands:", vim.inspect(found_commands))

os.exit(0)