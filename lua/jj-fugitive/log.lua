local M = {}

local ansi = require("jj-fugitive.ansi")

local BUF_PATTERN = "jj%-log"
local BUF_NAME = "jj-log"

--- Extract change ID from a displayed log line.
--- jj log lines look like: "@ tztvmqtt user@email 2026-03-17 3259cd17"
--- The change ID is the first alphanumeric word after graph symbols (@, ◆, ○, │, etc.)
local function change_id_from_line(line)
  if not line or line == "" or line:match("^%s*#") then
    return nil
  end
  local clean = ansi.parse_ansi_colors(line)
  -- Match the change ID: first word of 8+ lowercase alpha chars after graph symbols
  -- Graph symbols are: @, ◆, ○, │, ╮, ╯, ~, spaces, etc.
  local id = clean:match("^[│╮╯╭╰◆○@~%s]*([a-z][a-z]+)%s")
  if id and #id >= 8 then
    return id
  end
  return nil
end

--- Check if log output contains any commits.
local function has_commits(output)
  for line in output:gmatch("[^\n]+") do
    if change_id_from_line(line) then
      return true
    end
  end
  return false
end

--- Get jj log output with ANSI colors.
local function get_log(opts)
  opts = opts or {}
  local init = require("jj-fugitive.init")
  local args = { "log", "--color", "always" }

  if opts.limit then
    table.insert(args, "--limit")
    table.insert(args, tostring(opts.limit))
  end

  if opts.revisions then
    for _, rev in ipairs(opts.revisions) do
      table.insert(args, "-r")
      table.insert(args, rev)
    end
  end

  return init.run_jj(args)
end

--- Run a jj command and refresh log on success.
local function run_and_refresh(args, msg)
  local init = require("jj-fugitive.init")
  local result = init.run_jj(args)
  if result then
    if msg then
      vim.api.nvim_echo({ { msg, "MoreMsg" } }, false, {})
    end
    M.refresh()
  end
end

--- Setup keymaps for a detail buffer (show/diff opened from log).
local function setup_detail_keymaps(bufnr, kind, id)
  local ui = require("jj-fugitive.ui")

  ui.map(bufnr, "n", "q", "<cmd>close<CR>")

  ui.map(bufnr, "n", "g?", function()
    ui.help_popup("jj-fugitive " .. kind, {
      "Viewing " .. kind:lower() .. " for commit " .. id,
      "",
      "  q       Close",
      "  g?      This help",
    })
  end)
end

--- Setup keymaps for the log buffer (idempotent — safe to call on refresh).
local function setup_keymaps(bufnr)
  -- Guard: only set keymaps once per buffer
  local already = false
  pcall(function()
    already = vim.api.nvim_buf_get_var(bufnr, "jj_log_keymaps_set") == true
  end)
  if already then
    return
  end
  pcall(vim.api.nvim_buf_set_var, bufnr, "jj_log_keymaps_set", true)

  local ui = require("jj-fugitive.ui")

  local function get_change_id()
    return change_id_from_line(vim.api.nvim_get_current_line())
  end

  -- Show commit details
  ui.map(bufnr, "n", "<CR>", function()
    local id = get_change_id()
    if not id then
      return
    end
    local init = require("jj-fugitive.init")
    local result = init.run_jj({ "show", "--color", "always", "--git", id })
    if not result then
      return
    end

    local header = { "", "# Commit: " .. id, "# Press g? for help, q to close", "" }
    local bufname = "jj-show: " .. id
    local show_buf = ansi.create_colored_buffer(result, bufname, header, {
      prefix = "JjShow",
    })

    vim.cmd("split")
    vim.api.nvim_set_current_buf(show_buf)
    setup_detail_keymaps(show_buf, "Show", id)
    ui.set_statusline(show_buf, "jj-show: " .. id)
  end)

  -- Show diff for commit
  ui.map(bufnr, "n", "d", function()
    local id = get_change_id()
    if not id then
      return
    end
    local init = require("jj-fugitive.init")
    local result = init.run_jj({ "diff", "--color", "always", "--git", "-r", id })
    if not result then
      return
    end

    local header = { "", "# Diff: " .. id, "# Press g? for help, q to close", "" }
    local bufname = "jj-diff: " .. id
    local diff_buf = ansi.create_colored_buffer(result, bufname, header, {
      prefix = "JjDiff",
    })

    vim.cmd("split")
    vim.api.nvim_set_current_buf(diff_buf)
    setup_detail_keymaps(diff_buf, "Diff", id)
    ui.set_statusline(diff_buf, "jj-diff: " .. id)
  end)

  -- Edit at commit
  ui.map(bufnr, "n", "e", function()
    local id = get_change_id()
    if id then
      run_and_refresh({ "edit", id }, "Editing at " .. id)
    end
  end)

  -- New commit after this one
  ui.map(bufnr, "n", "n", function()
    local id = get_change_id()
    if id then
      run_and_refresh({ "new", id }, "New change after " .. id)
    end
  end)

  -- Squash into parent
  ui.map(bufnr, "n", "s", function()
    local id = get_change_id()
    if not id then
      return
    end
    local init = require("jj-fugitive.init")
    local desc = init.run_jj({ "log", "-r", id, "--no-graph", "-T", "description" })
    local summary = desc and desc:gsub("%s+$", ""):match("^[^\n]*") or ""
    local msg = "Squash " .. id
    if summary ~= "" then
      msg = msg .. ' ("' .. summary .. '")'
    end
    msg = msg .. " into its parent?"
    if ui.confirm(msg) then
      run_and_refresh({ "squash", "-r", id }, "Squashed " .. id)
    end
  end)

  -- Abandon commit
  ui.map(bufnr, "n", "A", function()
    local id = get_change_id()
    if not id then
      return
    end
    local init = require("jj-fugitive.init")
    local desc = init.run_jj({ "log", "-r", id, "--no-graph", "-T", "description" })
    local summary = desc and desc:gsub("%s+$", ""):match("^[^\n]*") or ""
    local msg = "Abandon " .. id
    if summary ~= "" then
      msg = msg .. ' ("' .. summary .. '")'
    end
    msg = msg .. "?"
    if ui.confirm(msg) then
      run_and_refresh({ "abandon", id }, "Abandoned " .. id)
    end
  end)

  -- Bookmark mode
  ui.map(bufnr, "n", "b", function()
    local id = get_change_id()
    if not id then
      return
    end
    local name = vim.fn.input("Bookmark name (create/move to " .. id .. "): ")
    if name and name ~= "" then
      -- Try set first (moves existing), fall back to create
      local init = require("jj-fugitive.init")
      local result = init.run_jj({ "bookmark", "set", name, "-r", id })
      if not result then
        result = init.run_jj({ "bookmark", "create", name, "-r", id })
      end
      if result then
        vim.api.nvim_echo({ { "Bookmark '" .. name .. "' -> " .. id, "MoreMsg" } }, false, {})
        M.refresh()
      end
    end
  end)

  -- Rebase: rd = rebase @ onto commit, rs = rebase source onto dest
  ui.map(bufnr, "n", "rd", function()
    local id = get_change_id()
    if id and ui.confirm("Rebase @ onto " .. id .. "?") then
      run_and_refresh({ "rebase", "-d", id }, "Rebased onto " .. id)
    end
  end)

  ui.map(bufnr, "n", "rs", function()
    local id = get_change_id()
    if not id then
      return
    end
    local source = vim.fn.input("Rebase source revision (onto " .. id .. "): ")
    if source and source ~= "" then
      run_and_refresh({ "rebase", "-s", source, "-d", id }, "Rebased " .. source .. " onto " .. id)
    end
  end)

  ui.map(bufnr, "n", "rb", function()
    local id = get_change_id()
    if not id then
      return
    end
    local branch = vim.fn.input("Rebase branch revision (onto " .. id .. "): ")
    if branch and branch ~= "" then
      run_and_refresh(
        { "rebase", "-b", branch, "-d", id },
        "Rebased branch " .. branch .. " onto " .. id
      )
    end
  end)

  -- Describe
  ui.map(bufnr, "n", "D", function()
    local id = get_change_id()
    if id then
      require("jj-fugitive.describe").describe(id)
    end
  end)

  -- Expand (show more commits)
  local function expand()
    local current_limit = 0
    pcall(function()
      current_limit = vim.api.nvim_buf_get_var(bufnr, "jj_log_limit")
    end)
    local new_limit = current_limit == 0 and 50 or current_limit + 50
    M.show({ revisions = { ".." }, limit = new_limit })
  end

  ui.map(bufnr, "n", "+", expand)
  ui.map(bufnr, "n", "=", expand)

  -- Refresh
  ui.map(bufnr, "n", "R", function()
    M.refresh()
  end)

  -- Close
  ui.map(bufnr, "n", "q", "<cmd>close<CR>")

  -- Help
  ui.map(bufnr, "n", "g?", function()
    ui.help_popup("jj-fugitive Log", {
      "Navigation:",
      "  j/k       Move through commits",
      "  +/=       Show more commits",
      "",
      "Commit actions:",
      "  <CR>      Show commit details",
      "  d         Show diff for commit",
      "  D         Describe (edit commit message)",
      "  e         Edit at commit (jj edit)",
      "  n         New change after commit (jj new)",
      "  s         Squash into parent (jj squash)",
      "  A         Abandon commit (jj abandon)",
      "",
      "Bookmark:",
      "  b         Create/move bookmark to commit",
      "",
      "Rebase:",
      "  rd        Rebase @ onto commit under cursor",
      "  rs        Rebase source onto commit (prompts for source)",
      "  rb        Rebase branch onto commit (prompts for branch)",
      "",
      "Other:",
      "  R         Refresh log",
      "  q         Close",
      "  g?        This help",
    }, { width = 60 })
  end)
end

--- Check if a log buffer exists.
function M.is_open()
  local ui = require("jj-fugitive.ui")
  return ui.find_buf(BUF_PATTERN) ~= nil
end

--- Refresh the current log view.
function M.refresh()
  local ui = require("jj-fugitive.ui")
  local bufnr = ui.find_buf(BUF_PATTERN)
  if not bufnr then
    return
  end

  -- Preserve limit
  local limit = 0
  pcall(function()
    limit = vim.api.nvim_buf_get_var(bufnr, "jj_log_limit")
  end)

  local opts = {}
  if limit > 0 then
    opts.limit = limit
    opts.revisions = { ".." }
  end

  local output = get_log(opts)
  if not output then
    return
  end

  local limit_text = opts.limit and string.format(" (limit: %d)", opts.limit) or ""
  local header = {
    "",
    "# jj Log" .. limit_text,
    "# Press g? for help",
    "",
  }

  ansi.update_colored_buffer(bufnr, output, header, {
    prefix = "JjLog",
  })

  setup_keymaps(bufnr)
end

--- Show the log view.
function M.show(opts)
  opts = opts or {}

  local output = get_log(opts)
  if not output then
    return
  end

  if not has_commits(output) then
    vim.api.nvim_echo({ { "No commits found", "WarningMsg" } }, false, {})
    return
  end

  local limit_text = opts.limit and string.format(" (limit: %d)", opts.limit) or ""
  local header = {
    "",
    "# jj Log" .. limit_text,
    "# Press g? for help",
    "",
  }

  -- Reuse existing log buffer if open
  local ui = require("jj-fugitive.ui")
  local existing = ui.find_buf(BUF_PATTERN)
  local bufnr

  if existing then
    bufnr = existing
    ansi.update_colored_buffer(bufnr, output, header, { prefix = "JjLog" })
  else
    bufnr = ansi.create_colored_buffer(output, BUF_NAME, header, { prefix = "JjLog" })
  end

  vim.api.nvim_buf_set_var(bufnr, "jj_log_limit", opts.limit or 0)

  setup_keymaps(bufnr)

  if not existing then
    ui.ensure_visible(bufnr)
  end

  -- Position cursor on first commit line
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for i, line in ipairs(lines) do
    if not line:match("^%s*#") and line ~= "" and change_id_from_line(line) then
      pcall(vim.api.nvim_win_set_cursor, 0, { i, 0 })
      break
    end
  end

  ui.set_statusline(bufnr, "jj-log")
end

return M
