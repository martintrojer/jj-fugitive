local M = {}

--- Open a describe buffer for the given revision.
function M.describe(rev) -- luacheck: ignore rev
  -- Phase 4 implementation
  vim.api.nvim_echo({ { "jj-fugitive: describe (Phase 4)", "MoreMsg" } }, false, {})
end

--- Open a commit buffer.
function M.commit()
  -- Phase 4 implementation
  vim.api.nvim_echo({ { "jj-fugitive: commit (Phase 4)", "MoreMsg" } }, false, {})
end

return M
