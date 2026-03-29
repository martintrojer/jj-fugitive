local M = {}

local BUF_PATTERN = "jj%-status"
local BUF_NAME = "jj-status"

--- Get jj status output.
local function get_status()
  local init = require("jj-fugitive")
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

--- Toggle inline diff for the file on the current line.
--- Inserts/removes diff lines below the status line.
local function toggle_inline_diff(bufnr)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_nr = cursor[1]
  local line = vim.api.nvim_buf_get_lines(bufnr, line_nr - 1, line_nr, false)[1]
  local file = file_from_line(line)
  if not file then
    return
  end

  -- Check if next line is already an inline diff (indented with 4 spaces)
  local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  if line_nr < #all_lines and (all_lines[line_nr + 1] or ""):match("^    ") then
    -- Collapse: find the end of the indented block
    local first = line_nr + 1 -- 1-indexed first diff line
    local last = first
    for i = first + 1, #all_lines do
      if all_lines[i]:match("^    ") then
        last = i
      else
        break
      end
    end
    -- Delete 1-indexed range [first, last] using 0-indexed API
    vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
    vim.api.nvim_buf_set_lines(bufnr, first - 1, last, false, {})
    vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
    vim.api.nvim_buf_set_option(bufnr, "modified", false)
    return
  end

  -- Expand: get diff and insert below
  local init = require("jj-fugitive")
  local diff_output = init.run_jj({ "diff", "--git", file })
  if not diff_output or diff_output:match("^%s*$") then
    return
  end

  local diff_lines = {}
  for _, dl in ipairs(vim.split(diff_output, "\n")) do
    if dl ~= "" then
      table.insert(diff_lines, "    " .. dl)
    end
  end

  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(bufnr, line_nr, line_nr, false, diff_lines)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
  vim.api.nvim_buf_set_option(bufnr, "modified", false)

  -- Add inline diff highlighting
  for i = line_nr, line_nr + #diff_lines - 1 do
    local dl = diff_lines[i - line_nr + 1]
    local hl
    if dl:match("^    %+") then
      hl = "DiffAdd"
    elseif dl:match("^    %-") then
      hl = "DiffDelete"
    elseif dl:match("^    @@") then
      hl = "DiffChange"
    end
    if hl then
      vim.api.nvim_buf_add_highlight(bufnr, -1, hl, i, 0, -1)
    end
  end
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

  -- Toggle inline diff (fugitive's = key)
  ui.map(bufnr, "n", "=", function()
    toggle_inline_diff(bufnr)
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
      local init = require("jj-fugitive")
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

  ui.map(bufnr, "n", "gu", function()
    require("jj-fugitive").undo()
  end)

  -- Show aliases
  ui.map(bufnr, "n", "ga", function()
    ui.show_aliases()
  end)

  -- Switch views
  ui.map(bufnr, "n", "gb", function()
    vim.cmd(ui.close_cmd())
    require("jj-fugitive.bookmark").show()
  end)

  ui.map(bufnr, "n", "gl", function()
    vim.cmd(ui.close_cmd())
    require("jj-fugitive.log").show()
  end)

  -- Close
  ui.map(bufnr, "n", "q", function()
    vim.cmd(ui.close_cmd())
  end)

  -- Help
  ui.map(bufnr, "n", "g?", function()
    ui.help_popup("jj-fugitive Status", {
      "Status view",
      "",
      "Actions:",
      "  <CR>/o   Open file",
      "  =        Toggle inline diff",
      "  d        Show diff for file",
      "  D        Side-by-side diff",
      "  x        Restore file from parent (@-)",
      "",
      "Views:",
      "  gb       Switch to bookmark view",
      "  gl       Switch to log view",
      "",
      "Other:",
      "  ga       Show jj aliases",
      "  gu       Undo last jj operation",
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

  -- Position cursor on first file line (skip headers)
  for i, line in ipairs(lines) do
    if file_from_line(line) then
      pcall(vim.api.nvim_win_set_cursor, 0, { i, 0 })
      break
    end
  end

  ui.set_statusline(bufnr, "jj-status")
end

return M
