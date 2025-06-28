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

vim.api.nvim_create_user_command("JLog", function(opts)
  jj_fugitive.log(opts.args)
end, {
  nargs = "*",
})

vim.api.nvim_create_user_command("JDiff", function(opts)
  jj_fugitive.diff(opts.args)
end, {
  nargs = "*",
})

vim.api.nvim_create_user_command("JCommit", function(opts)
  jj_fugitive.commit(opts.args)
end, {
  nargs = "*",
})

vim.api.nvim_create_user_command("JNew", function(opts)
  jj_fugitive.new(opts.args)
end, {
  nargs = "*",
})

vim.api.nvim_create_user_command("JNext", function()
  jj_fugitive.next()
end, {})

vim.api.nvim_create_user_command("JPrev", function()
  jj_fugitive.prev()
end, {})

vim.api.nvim_create_user_command("JEdit", function(opts)
  jj_fugitive.edit(opts.args)
end, {
  nargs = "*",
})

vim.api.nvim_create_user_command("JBookmark", function(opts)
  jj_fugitive.bookmark(opts.args)
end, {
  nargs = "*",
})
