local M = {}

-- Placeholder buffer name pattern
local BUF_PATTERN = "jj%-log"

--- Check if a log buffer is currently open.
function M.is_open()
  local ui = require("jj-fugitive.ui")
  return ui.find_buf(BUF_PATTERN) ~= nil
end

--- Refresh the log buffer if open.
function M.refresh()
  local ui = require("jj-fugitive.ui")
  local bufnr = ui.find_buf(BUF_PATTERN)
  if bufnr then
    -- Will be implemented in Phase 2
    M.show()
  end
end

--- Show the log view.
function M.show(opts) -- luacheck: ignore opts
  -- Phase 2 implementation
  vim.api.nvim_echo({ { "jj-fugitive: log view (Phase 2)", "MoreMsg" } }, false, {})
end

return M
