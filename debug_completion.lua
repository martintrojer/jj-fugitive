#!/usr/bin/env -S nvim --headless -l

vim.cmd("set rtp+=.")
vim.cmd("runtime plugin/jj-fugitive.lua")

local completion_module = require("jj-fugitive.completion")

print("Testing git subcommand completion:")
local git_completions = completion_module.complete_jj_command("git ", "J git ", 6)
print("Result:", vim.inspect(git_completions))

print("\nTesting bookmark subcommand completion:")
local bookmark_completions = completion_module.complete_jj_command("bookmark ", "J bookmark ", 10)
print("Result:", vim.inspect(bookmark_completions))

print("\nTesting basic completion:")
local basic_completions = completion_module.complete_jj_command("", "J ", 2)
print("Result:", vim.inspect(basic_completions))

os.exit(0)