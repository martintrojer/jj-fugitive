#!/usr/bin/env -S nvim --headless -l

vim.cmd("set rtp+=.")
vim.cmd("runtime plugin/jj-fugitive.lua")

local log_module = require("jj-fugitive.log")
local success, err = pcall(function()
  log_module.show_log({ limit = 10 })
end)

if not success then
  print("Error: " .. tostring(err))
  os.exit(1)
else
  print("Success: show_log with limit worked")
  os.exit(0)
end