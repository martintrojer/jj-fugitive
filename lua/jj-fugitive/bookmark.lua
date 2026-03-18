local M = {}

local BUF_PATTERN = "jj%-bookmarks"
local BUF_NAME = "jj-bookmarks"

--- Get bookmark list output.
local function get_bookmarks()
  local init = require("jj-fugitive")
  return init.run_jj({ "bookmark", "list", "--all" })
end

--- Extract bookmark name from the current line.
--- Bookmark lines look like: "main: qpvuntsm 3f35615d (empty) description"
--- or: "main (tracked): qpvuntsm 3f35615d description"
local function bookmark_from_line(line)
  if not line or line == "" or line:match("^%s*#") then
    return nil
  end
  -- Match bookmark name before the colon
  local name = line:match("^(%S+):")
  if not name then
    -- Handle indented lines (tracking info) — no bookmark name
    return nil
  end
  -- Strip tracking annotations like "(tracked)"
  name = name:gsub("%s*%(.-%)%s*", "")
  return name
end

--- Run a bookmark command and refresh.
local function run_and_refresh(args, msg)
  local init = require("jj-fugitive")
  local result = init.run_jj(args)
  if result then
    if msg then
      vim.api.nvim_echo({ { msg, "MoreMsg" } }, false, {})
    end
    M.refresh()
    init.refresh_log()
  end
end

--- Setup keymaps for the bookmark buffer.
local function setup_keymaps(bufnr)
  local ui = require("jj-fugitive.ui")

  -- Create bookmark
  ui.map(bufnr, "n", "c", function()
    local name = vim.fn.input("New bookmark name: ")
    if name and name ~= "" then
      local rev = vim.fn.input("At revision (default @): ")
      if rev == "" then
        rev = "@"
      end
      run_and_refresh({ "bookmark", "create", name, "-r", rev }, "Created bookmark: " .. name)
    end
  end)

  -- Delete bookmark
  ui.map(bufnr, "n", "d", function()
    local name = bookmark_from_line(vim.api.nvim_get_current_line())
    if name and ui.confirm("Delete bookmark '" .. name .. "'?") then
      run_and_refresh({ "bookmark", "delete", name }, "Deleted bookmark: " .. name)
    end
  end)

  -- Move bookmark to revision
  ui.map(bufnr, "n", "m", function()
    local name = bookmark_from_line(vim.api.nvim_get_current_line())
    if not name then
      return
    end
    local rev = vim.fn.input("Move '" .. name .. "' to revision: ")
    if rev and rev ~= "" then
      run_and_refresh(
        { "bookmark", "set", name, "-r", rev, "--allow-backwards" },
        "Moved " .. name .. " -> " .. rev
      )
    end
  end)

  -- Track remote bookmark
  ui.map(bufnr, "n", "t", function()
    local name = bookmark_from_line(vim.api.nvim_get_current_line())
    if name then
      run_and_refresh({ "bookmark", "track", name .. "@origin" }, "Tracking: " .. name)
    end
  end)

  -- Untrack remote bookmark
  ui.map(bufnr, "n", "u", function()
    local name = bookmark_from_line(vim.api.nvim_get_current_line())
    if name then
      run_and_refresh({ "bookmark", "untrack", name .. "@origin" }, "Untracked: " .. name)
    end
  end)

  -- Push bookmark
  ui.map(bufnr, "n", "p", function()
    local name = bookmark_from_line(vim.api.nvim_get_current_line())
    if name then
      run_and_refresh({ "git", "push", "--bookmark", name }, "Pushed: " .. name)
    end
  end)

  -- Fetch
  ui.map(bufnr, "n", "f", function()
    run_and_refresh({ "git", "fetch" }, "Fetched from remote")
  end)

  -- Refresh
  ui.map(bufnr, "n", "R", function()
    M.refresh()
  end)

  -- Close
  ui.map(bufnr, "n", "q", function()
    vim.cmd(ui.close_cmd())
  end)

  -- Help
  ui.map(bufnr, "n", "g?", function()
    ui.help_popup("jj-fugitive Bookmarks", {
      "Actions:",
      "  c       Create bookmark (prompts for name and revision)",
      "  d       Delete bookmark under cursor",
      "  m       Move bookmark to revision (prompts)",
      "  t       Track remote bookmark (origin)",
      "  u       Untrack remote bookmark",
      "",
      "Git integration:",
      "  p       Push bookmark to remote",
      "  f       Fetch from remote",
      "",
      "Other:",
      "  R       Refresh",
      "  q       Close",
      "  g?      This help",
    })
  end)
end

--- Format bookmark output into display lines.
local function format_lines(output)
  local lines = {
    "# jj Bookmarks",
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

--- Refresh the bookmark buffer if open.
function M.refresh()
  local ui = require("jj-fugitive.ui")
  local bufnr = ui.find_buf(BUF_PATTERN)
  if not bufnr then
    return
  end

  local output = get_bookmarks()
  if not output then
    return
  end

  ui.set_buf_lines(bufnr, format_lines(output))
  setup_keymaps(bufnr)
end

--- Show the bookmark management view.
function M.show()
  local output = get_bookmarks()
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
    vim.cmd("syntax match JjBookmarkHeader '^#.*'")
    vim.cmd("syntax match JjBookmarkName '^[a-zA-Z][a-zA-Z0-9_/-]*:'")
    vim.cmd("highlight default link JjBookmarkHeader Comment")
    vim.cmd("highlight default link JjBookmarkName Identifier")
  end)

  setup_keymaps(bufnr)

  if not existing then
    ui.ensure_visible(bufnr)
  end

  ui.set_statusline(bufnr, "jj-bookmarks")
end

return M
