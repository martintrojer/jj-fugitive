if vim.g.loaded_jj_fugitive == 1 then
  return
end
vim.g.loaded_jj_fugitive = 1

local jj_fugitive = require("jj-fugitive")

vim.api.nvim_create_user_command("Jj", function(opts)
  jj_fugitive.jj(opts.args)
end, {
  nargs = "*",
  complete = function(arglead, cmdline, cursorpos)
    return jj_fugitive.complete(arglead, cmdline, cursorpos)
  end,
})

vim.api.nvim_create_user_command("JjStatus", function()
  jj_fugitive.status()
end, {})

vim.api.nvim_create_user_command("JjLog", function(opts)
  jj_fugitive.log(opts.args)
end, {
  nargs = "*",
})

vim.api.nvim_create_user_command("JjDiff", function(opts)
  jj_fugitive.diff(opts.args)
end, {
  nargs = "*",
})

vim.api.nvim_create_user_command("JjCommit", function(opts)
  jj_fugitive.commit(opts.args)
end, {
  nargs = "*",
})

vim.api.nvim_create_user_command("JjNew", function(opts)
  jj_fugitive.new(opts.args)
end, {
  nargs = "*",
})

vim.api.nvim_create_user_command("JjNext", function()
  jj_fugitive.next()
end, {})

vim.api.nvim_create_user_command("JjPrev", function()
  jj_fugitive.prev()
end, {})

vim.api.nvim_create_user_command("JjEdit", function(opts)
  jj_fugitive.edit(opts.args)
end, {
  nargs = "*",
})

vim.api.nvim_create_user_command("JjBookmark", function(opts)
  jj_fugitive.bookmark(opts.args)
end, {
  nargs = "*",
})
