local M = {}

--- Show diff view.
function M.show(file) -- luacheck: ignore file
  -- Phase 3 implementation
  vim.api.nvim_echo({ { "jj-fugitive: diff view (Phase 3)", "MoreMsg" } }, false, {})
end

return M
