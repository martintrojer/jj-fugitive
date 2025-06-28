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

vim.api.nvim_create_user_command("JStatus", function()
  jj_fugitive.status()
end, {})

vim.api.nvim_create_user_command("JDiff", function(opts)
  jj_fugitive.diff(opts.args)
end, {
  nargs = "*",
})
