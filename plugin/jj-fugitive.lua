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

-- Minimal contextual help command (matches documentation)
vim.api.nvim_create_user_command("JHelp", function(opts)
  jj_fugitive.jhelp(opts.args)
end, {
  nargs = "*",
})

-- GBrowse-like command
vim.api.nvim_create_user_command("JBrowse", function()
  require("jj-fugitive.browse").browse()
end, { nargs = 0 })
