local core_ui = require("fugitive-core.ui")
local M = setmetatable({}, { __index = core_ui })

--- Show jj aliases in a help popup.
function M.show_aliases()
  local output = require("jj-fugitive").run_jj({ "config", "list", "aliases" })
  if not output or output == "" then
    M.warn("No jj aliases configured")
    return
  end

  local lines = { "Run with :J <alias>", "" }
  for line in output:gmatch("[^\n]+") do
    -- Format: aliases.name = ["cmd", "args"]
    local name, definition = line:match("^aliases%.([%w_-]+)%s*=%s*(.+)")
    if name then
      -- Clean up the array syntax for readability
      local args = definition:gsub("%[", ""):gsub("%]", ""):gsub('"', ""):gsub(", ", " ")
      table.insert(lines, "  " .. name .. "  →  jj " .. args)
    end
  end

  M.help_popup("jj Aliases", lines, { width = 70 })
end

--- Silently get file content at a revision (returns "" if file doesn't exist).
function M.file_at_rev(filename, rev)
  local repo_root = require("jj-fugitive").repo_root()
  if not repo_root then
    return ""
  end
  local result =
    vim.fn.system({ "jj", "file", "show", "root:" .. filename, "-r", rev, "-R", repo_root })
  if vim.v.shell_error ~= 0 then
    return ""
  end
  return result
end

return M
