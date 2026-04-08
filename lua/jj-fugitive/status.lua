local M = {}

local core_list = require("fugitive-core.views.list")

local BUF_PATTERN = "jj%-status"
local BUF_NAME = "jj-status"
local INLINE_VAR = "jj_status_inline_diffs"

local function get_status()
  return require("jj-fugitive").run_jj({ "status" })
end

local function file_from_line(line)
  if not line or line == "" or line:match("^%s*#") or line:match("^%s*$") then
    return nil
  end
  local filename = line:match("^%s*[MADR]%s+(.+)")
  if filename then
    local new_name = filename:match("^.+%s+->%s+(.+)")
    return new_name or filename
  end
  return nil
end

local function toggle_inline_diff(bufnr)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_nr = cursor[1]
  local line = vim.api.nvim_buf_get_lines(bufnr, line_nr - 1, line_nr, false)[1]
  if core_list.collapse_inline_at_cursor(bufnr, INLINE_VAR) then
    return
  end

  local file = file_from_line(line)
  if not file then
    return
  end

  -- Check if this filename already has an expanded diff — collapse it
  local state = core_list.get_inline_state(bufnr, INLINE_VAR)
  for i, item in ipairs(state) do
    if item.start_line == line_nr + 1 then
      vim.bo[bufnr].modifiable = true
      vim.api.nvim_buf_set_lines(bufnr, item.start_line - 1, item.end_line, false, {})
      vim.bo[bufnr].modifiable = false
      vim.bo[bufnr].modified = false

      local removed = item.end_line - item.start_line + 1
      table.remove(state, i)
      core_list.shift_inline_ranges(state, item.start_line - 1, -removed)
      core_list.set_inline_state(bufnr, INLINE_VAR, state)
      return
    end
  end

  local diff_output = require("jj-fugitive").run_jj({ "diff", "--git", file })
  if not diff_output or diff_output:match("^%s*$") then
    return
  end

  local diff_lines = {}
  for _, dl in ipairs(vim.split(diff_output, "\n")) do
    if dl ~= "" then
      table.insert(diff_lines, "    " .. dl)
    end
  end

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, line_nr, line_nr, false, diff_lines)
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].modified = false

  core_list.shift_inline_ranges(state, line_nr, #diff_lines)
  table.insert(state, {
    start_line = line_nr + 1,
    end_line = line_nr + #diff_lines,
    file = file,
    rev = "@",
  })
  core_list.set_inline_state(bufnr, INLINE_VAR, state)

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

local function comment_inline_diff(bufnr)
  local init = require("jj-fugitive")
  if not init.review_config then
    require("jj-fugitive.ui").warn("Review not available (redline.nvim not installed)")
    return
  end
  local ranges = core_list.get_inline_state(bufnr, INLINE_VAR)
  require("redline").comment(init.review_config, bufnr, function(b)
    return require("redline").extract_inline_diff_entry(b, ranges)
  end)
end

local function file_at_cursor(bufnr)
  return file_from_line(vim.api.nvim_get_current_line())
    or core_list.file_from_inline_state(bufnr, INLINE_VAR)
end

local function setup_keymaps(bufnr)
  local ui = require("jj-fugitive.ui")
  if ui.buf_var(bufnr, "jj_status_keymaps_set", false) then
    return
  end
  pcall(vim.api.nvim_buf_set_var, bufnr, "jj_status_keymaps_set", true)

  ui.map(bufnr, "n", "<CR>", function()
    local file = file_at_cursor(bufnr)
    if file then
      vim.cmd(ui.close_cmd())
      vim.cmd("edit " .. vim.fn.fnameescape(file))
    end
  end)

  ui.map(bufnr, "n", "o", function()
    local file = file_at_cursor(bufnr)
    if file then
      vim.cmd(ui.close_cmd())
      vim.cmd("split " .. vim.fn.fnameescape(file))
    end
  end)

  ui.map(bufnr, "n", "=", function()
    toggle_inline_diff(bufnr)
  end)

  ui.map(bufnr, "n", "cR", function()
    comment_inline_diff(bufnr)
  end)

  ui.map(bufnr, "n", "d", function()
    local file = file_at_cursor(bufnr)
    if file then
      require("jj-fugitive.diff").show(file)
    end
  end)

  ui.map(bufnr, "n", "D", function()
    local file = file_at_cursor(bufnr)
    if file then
      require("jj-fugitive.diff").show_sidebyside(file)
    end
  end)

  ui.map(bufnr, "n", "c", function() end)

  ui.map(bufnr, "n", "cc", function()
    require("jj-fugitive.describe").describe("@")
  end)

  ui.map(bufnr, "n", "S", function()
    require("jj-fugitive").run_jj_terminal("split")
  end)

  ui.map(bufnr, "n", "x", function()
    local file = file_at_cursor(bufnr)
    if file and ui.confirm("Restore " .. file .. " from parent") then
      local result = require("jj-fugitive").run_jj({ "restore", "--from", "@-", file })
      if result then
        ui.info("Restored: " .. file)
        M.refresh()
      end
    end
  end)

  ui.map(bufnr, "n", "gu", function()
    require("jj-fugitive").undo()
  end)

  ui.map(bufnr, "n", "ga", function()
    ui.show_aliases()
  end)

  local init = require("jj-fugitive")
  ui.setup_view_keymaps(bufnr, {
    log = function()
      vim.cmd(ui.close_cmd())
      require("jj-fugitive.log").show()
    end,
    bookmark = function()
      vim.cmd(ui.close_cmd())
      require("jj-fugitive.bookmark").show()
    end,
    review = init.review_config and function()
      require("redline").show(init.review_config)
    end,
    refresh = function()
      M.refresh()
    end,
    help = function()
      ui.help_popup("jj-fugitive Status", {
        "Status view",
        "",
        "Actions:",
        "  <CR>     Open file",
        "  o        Open file in split",
        "  =        Toggle inline diff",
        "  cR       Add review comment from inline diff",
        "  gR       Open review buffer",
        "  d        Show diff for file",
        "  D        Side-by-side diff",
        "  cc       Describe working copy",
        "  S        Split working copy (jj split TUI)",
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
    end,
  })
end

local function format_lines(output)
  local lines = {
    "",
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

function M.refresh()
  core_list.refresh({
    get_data = get_status,
    format_lines = format_lines,
    buf_pattern = BUF_PATTERN,
  })
end

function M.show()
  core_list.show({
    get_data = get_status,
    format_lines = format_lines,
    buf_pattern = BUF_PATTERN,
    buf_name = BUF_NAME,
    statusline = "jj-status",
    first_item = file_from_line,
    setup = function(bufnr, is_new)
      core_list.set_inline_state(bufnr, INLINE_VAR, {})
      if is_new then
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
      end
      setup_keymaps(bufnr)
    end,
  })
end

return M
