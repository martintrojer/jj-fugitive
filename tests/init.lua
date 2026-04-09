-- Test runner for jj-fugitive
-- Run with: nvim --headless -u tests/init.lua

vim.opt.rtp:prepend(".")

-- Load fugitive-core (sibling dir locally, deps in CI)
local core_path = vim.fn.fnamemodify(".", ":p:h:h") .. "/fugitive-core.nvim"
if vim.fn.isdirectory(core_path) == 1 then
  vim.opt.rtp:prepend(core_path)
end

local ok = pcall(vim.cmd, "packadd mini.nvim")
if not ok then
  vim.opt.rtp:append(vim.fn.expand("~/.local/share/nvim/site/pack/deps/opt/mini.nvim"))
end

require("mini.test").setup()
MiniTest.run()
