#!/usr/bin/env -S nvim --headless -l

vim.cmd("set rtp+=.")
vim.cmd("runtime plugin/jj-fugitive.lua")

local completion_module = require("jj-fugitive.completion")

-- Test the completion function step by step
print("=== Testing completion function logic ===")

-- Test 1: git subcommand completion
print("\n1. Testing git subcommand completion")
print("   Input: arglead='', cmdline='J git ', cursorpos=6")

local arglead = ""
local cmdline = "J git "
local cursorpos = 6

-- Parse the command line like the function does
local parts = vim.split(cmdline, "%s+")
print("   Parsed parts:", vim.inspect(parts))

-- Remove the :J command itself
if parts[1] == "J" then
  table.remove(parts, 1)
end
print("   After removing J:", vim.inspect(parts))

-- Remove empty parts
local filtered_parts = {}
for _, part in ipairs(parts) do
  if part ~= "" then
    table.insert(filtered_parts, part)
  end
end
parts = filtered_parts
print("   After filtering empty:", vim.inspect(parts))

-- Check the conditions
print("   #parts:", #parts)
print("   cmdline:match('%s$'):", cmdline:match("%s$") and true or false)

-- This should trigger subcommand completion
local main_command = parts[1]
print("   Main command:", main_command)

-- Test has_subcommands
print("   Testing has_subcommands...")
local result = completion_module.complete_jj_command(arglead, cmdline, cursorpos)
print("   Final result:", vim.inspect(result))

print("\n2. Testing bookmark subcommand completion")
print("   Input: arglead='', cmdline='J bookmark ', cursorpos=10")

arglead = ""
cmdline = "J bookmark "
cursorpos = 10

result = completion_module.complete_jj_command(arglead, cmdline, cursorpos)
print("   Final result:", vim.inspect(result))

os.exit(0)