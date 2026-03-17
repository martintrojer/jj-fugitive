local M = {}

local BUF_PATTERN = "jj%-status"
local BUF_NAME = "jj-status"

--- Get jj status output.
local function get_status()
  local init = require("jj-fugitive.init")
  return init.run_jj({ "status" })
end

--- Extract filename from a status line like "M file1.txt" or "A file2.txt".
local function file_from_line(line)
  if not line or line == "" or line:match("^%s*#") or line:match("^%s*$") then
    return nil
  end
  -- Match status lines: "M file.txt", "A file.txt", "D file.txt", "R old -> new"
  local filename = line:match("^%s*[MADR]%s+(.+)")
  if filename then
    -- Handle renames: "old -> new"
    local new_name = filename:match("^.+%s+->%s+(.+)")
    return new_name or filename
  end
  return nil
end

--- Setup keymaps for the status buffer.
local function setup_keymaps(bufnr)
  local ui = require("jj-fugitive.ui")

  -- Open file
  ui.map(bufnr, "n", "<CR>", function()
    local file = file_from_line(vim.api.nvim_get_current_line())
    if file then
      vim.cmd("close")
      vim.cmd("edit " .. vim.fn.fnameescape(file))
    end
  end)

  ui.map(bufnr, "n", "o", function()
    local file = file_from_line(vim.api.nvim_get_current_line())
    if file then
      vim.cmd("close")
      vim.cmd("edit " .. vim.fn.fnameescape(file))
    end
  end)

  -- Diff file
  ui.map(bufnr, "n", "d", function()
    local file = file_from_line(vim.api.nvim_get_current_line())
    if file then
      require("jj-fugitive.diff").show(file)
    end
  end)

  -- Side-by-side diff
  ui.map(bufnr, "n", "D", function()
    local file = file_from_line(vim.api.nvim_get_current_line())
    if file then
      require("jj-fugitive.diff").show_sidebyside(file)
    end
  end)

  -- Restore file from parent
  ui.map(bufnr, "n", "x", function()
    local file = file_from_line(vim.api.nvim_get_current_line())
    if file and ui.confirm("Restore " .. file .. " from parent?") then
      local init = require("jj-fugitive.init")
      local result = init.run_jj({ "restore", "--from", "@-", file })
      if result then
        vim.api.nvim_echo({ { "Restored: " .. file, "MoreMsg" } }, false, {})
        M.refresh()
      end
    end
  end)

  -- Refresh
  ui.map(bufnr, "n", "R", function()
    M.refresh()
  end)

  -- Close
  ui.map(bufnr, "n", "q", "<cmd>close<CR>")

  -- Help
  ui.map(bufnr, "n", "g?", function()
    ui.help_popup("jj-fugitive Status", {
      "Actions:",
      "  <CR>/o   Open file",
      "  d        Show diff for file",
      "  D        Side-by-side diff",
      "  x        Restore file from parent (@-)",
      "",
      "Other:",
      "  R        Refresh",
      "  q        Close",
      "  g?       This help",
    })
  end)
end

--- Format status output into display lines.
local function format_lines(output)
  local lines = {
    "# jj Status",
    "# Press g? for help",
    "",
  }
  for _, line in ipairs(vim.split(output, "\n")) do
    if line ~= "" then
      table.insert(lines, line)
    end
  end
  return lines
end

--- Refresh the status buffer if open.
function M.refresh()
  local ui = require("jj-fugitive.ui")
  local bufnr = ui.find_buf(BUF_PATTERN)
  if not bufnr then
    return
  end

  local output = get_status()
  if not output then
    return
  end

  ui.set_buf_lines(bufnr, format_lines(output))
end

--- Show the status view.
function M.show()
  local output = get_status()
  if not output then
    return
  end

  local lines = format_lines(output)

  local ui = require("jj-fugitive.ui")
  local existing = ui.find_buf(BUF_PATTERN)
  local bufnr

  if existing then
    bufnr = existing
    ui.set_buf_lines(bufnr, lines)
  else
    bufnr = ui.create_scratch_buffer({ name = BUF_NAME })
    ui.set_buf_lines(bufnr, lines)
  end

  -- Highlighting
  vim.api.nvim_buf_call(bufnr, function()
    vim.cmd("syntax match JjStatusHeader '^#.*'")
    vim.cmd("syntax match JjStatusModified '^M .*'")
    vim.cmd("syntax match JjStatusAdded '^A .*'")
    vim.cmd("syntax match JjStatusDeleted '^D .*'")
    vim.cmd("syntax match JjStatusRenamed '^R .*'")
    vim.cmd("syntax match JjStatusSection '^Working copy.*\\|^Parent commit.*'")
    vim.cmd("highlight default link JjStatusHeader Comment")
    vim.cmd("highlight default link JjStatusModified DiffChange")
    vim.cmd("highlight default link JjStatusAdded DiffAdd")
    vim.cmd("highlight default link JjStatusDeleted DiffDelete")
    vim.cmd("highlight default link JjStatusRenamed DiffText")
    vim.cmd("highlight default link JjStatusSection Title")
  end)

  setup_keymaps(bufnr)

  if not existing then
    ui.ensure_visible(bufnr)
  end

  ui.set_statusline(bufnr, "jj-status")
end

return M
