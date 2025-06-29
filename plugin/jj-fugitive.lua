if vim.g.loaded_jj_fugitive == 1 then
  return
end
vim.g.loaded_jj_fugitive = 1

local jj_fugitive = require("jj-fugitive")

vim.api.nvim_create_user_command("J", function(opts)
  jj_fugitive.jj(opts.args)
end, {
  nargs = "*",
  complete = function(arglead, cmdline, cursorpos)
    return jj_fugitive.complete(arglead, cmdline, cursorpos)
  end,
})

-- Add a command to show inline help for jj commands
vim.api.nvim_create_user_command("JHelp", function(opts)
  local completion_module = require("jj-fugitive.completion")
  if opts.args == "" then
    completion_module.show_inline_help("J ")
  else
    completion_module.show_inline_help("J " .. opts.args)
  end
end, {
  nargs = "*",
  desc = "Show inline help for jj commands and flags",
})

-- Create a key mapping for showing help during command input
-- This is a convenience function that users can map to a key
vim.api.nvim_create_user_command("JHelpPopup", function()
  local completion_module = require("jj-fugitive.completion")
  local cmdline = vim.fn.getcmdline()
  completion_module.show_inline_help(cmdline)
end, {
  desc = "Show help popup for current command line (use during :J command input)",
})
