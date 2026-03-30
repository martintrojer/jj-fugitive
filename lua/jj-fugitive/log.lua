local M = {}

local ansi = require("jj-fugitive.ansi")
local ui = require("jj-fugitive.ui")

local BUF_PATTERN = "jj%-log"
local BUF_NAME = "jj-log"
local LOG_REV_MARKER = "JJREV<"
local DEFAULT_LOG_TEMPLATE = "builtin_log_compact"
local COMFORTABLE_LOG_TEMPLATE = "builtin_log_comfortable"

--- Strip machine-readable revision markers from log output and keep a map from
--- displayed line number (within the log body) to revision ID.
local function extract_log_metadata(output)
  local cleaned_lines = {}
  local line_rev_ids = {}
  local lines = vim.split(output or "", "\n", { plain = true })

  if lines[#lines] == "" then
    table.remove(lines)
  end

  for i, line in ipairs(lines) do
    local prefix, rev, suffix = line:match("^(.-)" .. LOG_REV_MARKER .. "([0-9a-f]+)>(.*)$")
    if rev then
      table.insert(cleaned_lines, prefix .. suffix)
      line_rev_ids[i] = rev
    else
      table.insert(cleaned_lines, line)
    end
  end

  return table.concat(cleaned_lines, "\n"), line_rev_ids
end

--- Trim the synthetic trailing blank line from jj output so buffer rendering
--- doesn't add an extra empty row at the end of the log view.
local function trim_trailing_blank_line(output)
  local lines = vim.split(output or "", "\n", { plain = true })
  if lines[#lines] == "" then
    table.remove(lines)
  end
  return table.concat(lines, "\n")
end

--- Check if log output contains any commits.
local function has_commits(line_rev_ids)
  return next(line_rev_ids) ~= nil
end

local function build_log_args(opts, template)
  local args = { "log", "--color", "always" }

  if template then
    table.insert(args, "-T")
    table.insert(args, template)
  end

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

  return args
end

local function get_default_log_template(init)
  local template = init.run_jj({ "config", "get", "templates.log" })
  if not template then
    return DEFAULT_LOG_TEMPLATE
  end

  template = template:gsub("%s+$", "")
  if template == "" then
    return DEFAULT_LOG_TEMPLATE
  end

  return template
end

local function get_log(opts)
  opts = opts or {}
  local init = require("jj-fugitive")
  local effective_template = opts.template or get_default_log_template(init)
  -- Embed rev markers into the template so we only need one jj call.
  -- Markers are plain text (no ANSI) so they survive color output and
  -- can be stripped cleanly by extract_log_metadata.
  local marked_template = '"'
    .. LOG_REV_MARKER
    .. '" ++ stringify(commit_id.short()) ++ ">" ++ ('
    .. effective_template
    .. ")"

  local marked_output = init.run_jj(build_log_args(opts, marked_template))
  if not marked_output then
    return nil
  end

  local visible_output, line_rev_ids = extract_log_metadata(marked_output)
  return trim_trailing_blank_line(visible_output), line_rev_ids
end

--- Determine the working copy source: @ if non-empty, @- otherwise.
local function working_copy_source()
  local init = require("jj-fugitive")
  local is_empty = init.run_jj({ "log", "-r", "@", "--no-graph", "-T", "empty" })
  return (is_empty and is_empty:match("true")) and "@-" or "@"
end

--- Store rev line mapping on a buffer.
local function set_rev_lines(bufnr, line_rev_ids, header_size)
  local rev_lines = {}
  for line_nr, rev in pairs(line_rev_ids) do
    rev_lines[tostring(line_nr + header_size)] = rev
  end
  vim.api.nvim_buf_set_var(bufnr, "jj_log_rev_lines", rev_lines)
  return rev_lines
end

--- Run a jj command and refresh log on success.
local function run_and_refresh(args, msg)
  local init = require("jj-fugitive")
  local result = init.run_jj(args)
  if result then
    if msg then
      vim.api.nvim_echo({ { msg, "MoreMsg" } }, false, {})
    end
    M.refresh()
  end
end

--- Format a revision as "change_id (commit_id)" for prompts.
--- Results are cached and cleared on each refresh.
local rev_label_cache = {}

local function rev_label(rev)
  if rev_label_cache[rev] then
    return rev_label_cache[rev]
  end
  local init = require("jj-fugitive")
  local out = init.run_jj({
    "log",
    "-r",
    rev,
    "--no-graph",
    "-T",
    'change_id.short() ++ " (" ++ commit_id.short() ++ ")"',
  })
  if not out then
    return rev
  end

  out = out:gsub("%s+$", "")
  local label = out ~= "" and out or rev
  rev_label_cache[rev] = label
  return label
end

--- Open side-by-side diff for a specific file at a revision.
local function sidebyside_at_rev(filename, rev)
  local current = ui.file_at_rev(filename, rev)
  local parent = ui.file_at_rev(filename, rev .. "-")

  ui.open_sidebyside(
    parent,
    filename .. " (" .. rev .. "-)",
    current,
    filename .. " (" .. rev .. ")",
    filename
  )
end

--- Setup keymaps for a detail buffer (show/diff opened from log).
function M.setup_detail_keymaps(bufnr, kind, id)
  ui.map(bufnr, "n", "q", function()
    vim.cmd(ui.close_cmd())
  end)

  -- Side-by-side diff (available in both show and diff views)
  ui.map(bufnr, "n", "D", function()
    local init = require("jj-fugitive")
    local files_output = init.run_jj({ "diff", "--name-only", "-r", id })
    if not files_output then
      return
    end

    local files = {}
    for _, f in ipairs(vim.split(files_output, "\n")) do
      if f:match("%S") then
        table.insert(files, f)
      end
    end

    if #files == 0 then
      vim.api.nvim_echo({ { "No files changed", "WarningMsg" } }, false, {})
      return
    end

    if #files == 1 then
      sidebyside_at_rev(files[1], id)
      return
    end

    vim.ui.select(files, { prompt = "Side-by-side diff for:" }, function(choice)
      if choice then
        sidebyside_at_rev(choice, id)
      end
    end)
  end)

  ui.map(bufnr, "n", "g?", function()
    ui.help_popup("jj-fugitive " .. kind, {
      kind .. " for commit " .. id,
      "",
      "Actions:",
      "  D       Side-by-side diff (pick file)",
      "",
      "Other:",
      "  q       Close",
      "  g?      This help",
    })
  end)
end

--- Setup keymaps for the log buffer (idempotent — safe to call on refresh).
local function setup_keymaps(bufnr)
  -- Guard: only set keymaps once per buffer
  if ui.buf_var(bufnr, "jj_log_keymaps_set", false) then
    return
  end
  pcall(vim.api.nvim_buf_set_var, bufnr, "jj_log_keymaps_set", true)

  local function get_rev_id()
    local rev_lines = ui.buf_var(bufnr, "jj_log_rev_lines", {})
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    for i = cursor_line, 1, -1 do
      local rev = rev_lines[tostring(i)]
      if rev then
        return rev
      end
    end
    return nil
  end

  local function toggle_comfortable()
    local template = ui.buf_var(bufnr, "jj_log_template", DEFAULT_LOG_TEMPLATE)
    local next_template = template == COMFORTABLE_LOG_TEMPLATE and DEFAULT_LOG_TEMPLATE
      or COMFORTABLE_LOG_TEMPLATE
    local current_limit = ui.buf_var(bufnr, "jj_log_limit", 0)
    M.show({
      revisions = { ".." },
      limit = current_limit > 0 and current_limit or nil,
      template = next_template,
    })
    vim.api.nvim_echo({
      { "Log layout: ", "MoreMsg" },
      { next_template == COMFORTABLE_LOG_TEMPLATE and "comfortable" or "compact", "MoreMsg" },
    }, false, {})
  end

  -- Show commit details
  ui.map(bufnr, "n", "<CR>", function()
    local id = get_rev_id()
    if not id then
      return
    end
    local init = require("jj-fugitive")
    local result = init.run_jj({ "show", "--color", "always", "--git", id })
    if not result then
      return
    end

    local header = { "", "# Commit: " .. id, "# Press g? for help, q to close", "" }
    local bufname = "jj-show: " .. id
    local show_buf = ansi.create_colored_buffer(result, bufname, header, {
      prefix = "JjShow",
    })

    ui.open_pane()
    vim.api.nvim_set_current_buf(show_buf)
    M.setup_detail_keymaps(show_buf, "Show", id)
    ui.set_statusline(show_buf, "jj-show: " .. id)
  end)

  -- Show diff for commit
  ui.map(bufnr, "n", "d", function()
    local id = get_rev_id()
    if not id then
      return
    end
    local init = require("jj-fugitive")
    local result = init.run_jj({ "diff", "--color", "always", "--git", "-r", id })
    if not result then
      return
    end

    local header = { "", "# Diff: " .. id, "# Press g? for help, q to close", "" }
    local bufname = "jj-diff: " .. id
    local diff_buf = ansi.create_colored_buffer(result, bufname, header, {
      prefix = "JjDiff",
    })

    ui.open_pane()
    vim.api.nvim_set_current_buf(diff_buf)
    M.setup_detail_keymaps(diff_buf, "Diff", id)
    ui.set_statusline(diff_buf, "jj-diff: " .. id)
  end)

  -- Edit at commit
  ui.map(bufnr, "n", "e", function()
    local id = get_rev_id()
    if id then
      run_and_refresh({ "edit", id }, "Editing at " .. id)
    end
  end)

  -- New commit after this one
  ui.map(bufnr, "n", "n", function()
    local id = get_rev_id()
    if id then
      run_and_refresh({ "new", id }, "New change after " .. id)
    end
  end)

  -- Squash @/@- into cursor
  ui.map(bufnr, "n", "gqw", function()
    local id = get_rev_id()
    if not id then
      return
    end
    local source = working_copy_source()
    local label = rev_label(id)
    if ui.confirm("Squash " .. source .. " into " .. label .. "?") then
      run_and_refresh(
        { "squash", "-r", source, "--into", id },
        "Squashed " .. source .. " into " .. label
      )
    end
  end)

  -- Squash prompted source into cursor (lowercase = prompt source, cursor is dest)
  ui.map(bufnr, "n", "gqs", function()
    local id = get_rev_id()
    if not id then
      return
    end
    local label = rev_label(id)
    local source = vim.fn.input("Squash revision into " .. label .. ": ")
    if source and source ~= "" then
      if ui.confirm("Squash " .. source .. " into " .. label .. "?") then
        run_and_refresh(
          { "squash", "-r", source, "--into", id },
          "Squashed " .. source .. " into " .. label
        )
      end
    end
  end)

  -- Squash cursor into prompted destination (uppercase = cursor is source)
  ui.map(bufnr, "n", "gqS", function()
    local id = get_rev_id()
    if not id then
      return
    end
    local label = rev_label(id)
    local into = vim.fn.input("Squash " .. label .. " into revision: ")
    if into and into ~= "" then
      if ui.confirm("Squash " .. label .. " into " .. into .. "?") then
        run_and_refresh(
          { "squash", "-r", id, "--into", into },
          "Squashed " .. label .. " into " .. into
        )
      end
    end
  end)

  -- Abandon commit
  ui.map(bufnr, "n", "A", function()
    local id = get_rev_id()
    if id and ui.confirm("Abandon " .. rev_label(id) .. "?") then
      run_and_refresh({ "abandon", id }, "Abandoned " .. id)
    end
  end)

  -- Bookmark mode
  ui.map(bufnr, "n", "b", function()
    local id = get_rev_id()
    if not id then
      return
    end
    local name = vim.fn.input("Bookmark name (create/move to " .. id .. "): ")
    if name and name ~= "" then
      -- Try set first (moves existing), fall back to create
      local init = require("jj-fugitive")
      local result = init.run_jj({ "bookmark", "set", name, "-r", id, "--allow-backwards" })
      if not result then
        result = init.run_jj({ "bookmark", "create", name, "-r", id })
      end
      if result then
        vim.api.nvim_echo({ { "Bookmark '" .. name .. "' -> " .. id, "MoreMsg" } }, false, {})
        M.refresh()
      end
    end
  end)

  -- Rebase helpers: lowercase prompts source, uppercase uses cursor as source.
  ui.map(bufnr, "n", "grw", function()
    local id = get_rev_id()
    if not id then
      return
    end
    local source = working_copy_source()
    local label = rev_label(id)
    if ui.confirm("Rebase " .. source .. " onto " .. label .. "?") then
      run_and_refresh(
        { "rebase", "-s", source, "-d", id },
        "Rebased " .. source .. " onto " .. label
      )
    end
  end)

  ui.map(bufnr, "n", "grs", function()
    local id = get_rev_id()
    if not id then
      return
    end
    local label = rev_label(id)
    local source = vim.fn.input("Rebase source+desc onto " .. label .. ": ")
    if source and source ~= "" then
      if ui.confirm("Rebase " .. source .. " onto " .. label .. "?") then
        run_and_refresh(
          { "rebase", "-s", source, "-d", id },
          "Rebased " .. source .. " onto " .. label
        )
      end
    end
  end)

  ui.map(bufnr, "n", "grS", function()
    local id = get_rev_id()
    if not id then
      return
    end
    local label = rev_label(id)
    local dest = vim.fn.input("Rebase " .. label .. " and descendants onto revision: ")
    if dest and dest ~= "" then
      if ui.confirm("Rebase " .. label .. " and descendants onto " .. dest .. "?") then
        run_and_refresh(
          { "rebase", "-s", id, "-d", dest },
          "Rebased " .. label .. " and descendants onto " .. dest
        )
      end
    end
  end)

  ui.map(bufnr, "n", "grb", function()
    local id = get_rev_id()
    if not id then
      return
    end
    local label = rev_label(id)
    local branch = vim.fn.input("Rebase branch onto " .. label .. ": ")
    if branch and branch ~= "" then
      if ui.confirm("Rebase branch " .. branch .. " onto " .. label .. "?") then
        run_and_refresh(
          { "rebase", "-b", branch, "-d", id },
          "Rebased branch " .. branch .. " onto " .. label
        )
      end
    end
  end)

  -- Rebase cursor's branch onto prompted destination
  ui.map(bufnr, "n", "grB", function()
    local id = get_rev_id()
    if not id then
      return
    end
    local label = rev_label(id)
    local dest = vim.fn.input("Rebase branch of " .. label .. " onto revision: ")
    if dest and dest ~= "" then
      if ui.confirm("Rebase branch of " .. label .. " onto " .. dest .. "?") then
        run_and_refresh(
          { "rebase", "-b", id, "-d", dest },
          "Rebased branch of " .. label .. " onto " .. dest
        )
      end
    end
  end)

  -- Rebase single revision (children stay) onto cursor
  ui.map(bufnr, "n", "grr", function()
    local id = get_rev_id()
    if not id then
      return
    end
    local label = rev_label(id)
    local rev = vim.fn.input("Rebase single revision onto " .. label .. ": ")
    if rev and rev ~= "" then
      if ui.confirm("Rebase " .. rev .. " onto " .. label .. "?") then
        run_and_refresh({ "rebase", "-r", rev, "-d", id }, "Rebased " .. rev .. " onto " .. label)
      end
    end
  end)

  -- Extract cursor revision and move it elsewhere
  ui.map(bufnr, "n", "grR", function()
    local id = get_rev_id()
    if not id then
      return
    end
    local label = rev_label(id)
    local dest = vim.fn.input("Extract " .. label .. " onto revision: ")
    if dest and dest ~= "" then
      if ui.confirm("Extract " .. label .. " onto " .. dest .. "?") then
        run_and_refresh(
          { "rebase", "-r", id, "-d", dest },
          "Extracted " .. label .. " onto " .. dest
        )
      end
    end
  end)

  -- Insert revision after cursor in stack
  ui.map(bufnr, "n", "gra", function()
    local id = get_rev_id()
    if not id then
      return
    end
    local label = rev_label(id)
    local rev = vim.fn.input("Insert revision after " .. label .. ": ")
    if rev and rev ~= "" then
      if ui.confirm("Insert " .. rev .. " after " .. label .. "?") then
        run_and_refresh(
          { "rebase", "-r", rev, "--after", id },
          "Inserted " .. rev .. " after " .. label
        )
      end
    end
  end)

  -- Move cursor revision after another revision in stack
  ui.map(bufnr, "n", "grA", function()
    local id = get_rev_id()
    if not id then
      return
    end
    local label = rev_label(id)
    local dest = vim.fn.input("Insert " .. label .. " after revision: ")
    if dest and dest ~= "" then
      if ui.confirm("Insert " .. label .. " after " .. dest .. "?") then
        run_and_refresh(
          { "rebase", "-r", id, "--after", dest },
          "Inserted " .. label .. " after " .. dest
        )
      end
    end
  end)

  -- Block built-in keys that error on read-only buffer
  -- Mapping to a function (not <Nop>) lets Neovim still wait for multi-key sequences
  ui.map(bufnr, "n", "c", function() end)
  ui.map(bufnr, "n", "r", function() end)

  -- Describe (cc like fugitive's commit)
  ui.map(bufnr, "n", "cc", function()
    local id = get_rev_id()
    if id then
      require("jj-fugitive.describe").describe(id)
    end
  end)

  -- Expand (show more commits)
  local function expand()
    local current_limit = ui.buf_var(bufnr, "jj_log_limit", 0)
    local new_limit = current_limit == 0 and 50 or current_limit + 50
    local template = ui.buf_var(bufnr, "jj_log_template", DEFAULT_LOG_TEMPLATE)
    M.show({ revisions = { ".." }, limit = new_limit, template = template })
  end

  ui.map(bufnr, "n", "+", expand)
  ui.map(bufnr, "n", "=", expand)
  ui.map(bufnr, "n", "gC", toggle_comfortable)

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

  ui.map(bufnr, "n", "gs", function()
    vim.cmd(ui.close_cmd())
    require("jj-fugitive.status").show()
  end)

  -- Close
  ui.map(bufnr, "n", "q", function()
    vim.cmd(ui.close_cmd())
  end)

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
      "  cc        Describe (edit commit message)",
      "  e         Edit at commit (jj edit)",
      "  n         New change after commit (jj new)",
      "  b         Create/move bookmark to commit",
      "  A         Abandon commit (jj abandon)",
      "",
      "Rebase:",
      "  grw       Rebase @/@- onto cursor",
      "  grs       Rebase prompted source+desc onto cursor",
      "  grS       Rebase cursor+desc onto prompted destination",
      "  grr       Rebase prompted revision onto cursor (children stay)",
      "  grR       Rebase cursor onto prompted destination (children stay)",
      "  grb       Rebase prompted branch onto cursor",
      "  grB       Rebase cursor branch onto prompted destination",
      "  gra       Insert prompted revision after cursor",
      "  grA       Insert cursor after prompted destination",
      "",
      "Squash:",
      "  gqw       Squash @/@- into cursor",
      "  gqs       Squash prompted revision into cursor",
      "  gqS       Squash cursor into prompted revision",
      "",
      "Views:",
      "  gb        Switch to bookmark view",
      "  gC        Toggle compact/comfortable log layout",
      "  gs        Switch to status view",
      "",
      "Other:",
      "  ga        Show jj aliases",
      "  gu        Undo last jj operation",
      "  R         Refresh",
      "  q         Close",
      "  g?        This help",
    }, { width = 68 })
  end)
end

--- Check if a log buffer exists.
function M.is_open()
  return ui.find_buf(BUF_PATTERN) ~= nil
end

--- Refresh the current log view.
function M.refresh()
  rev_label_cache = {}
  local bufnr = ui.find_buf(BUF_PATTERN)
  if not bufnr then
    return
  end

  -- Preserve limit
  local limit = ui.buf_var(bufnr, "jj_log_limit", 0)
  local template = ui.buf_var(bufnr, "jj_log_template", DEFAULT_LOG_TEMPLATE)

  local opts = { template = template }
  if limit > 0 then
    opts.limit = limit
    opts.revisions = { ".." }
  end

  local output, line_rev_ids = get_log(opts)
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
  set_rev_lines(bufnr, line_rev_ids, #header)

  setup_keymaps(bufnr)
end

--- Show the log view.
function M.show(opts)
  opts = opts or {}

  local output, line_rev_ids = get_log(opts)
  if not output then
    return
  end

  if not has_commits(line_rev_ids) then
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
  local existing = ui.find_buf(BUF_PATTERN)
  local bufnr

  if existing then
    bufnr = existing
    ansi.update_colored_buffer(bufnr, output, header, { prefix = "JjLog" })
  else
    bufnr = ansi.create_colored_buffer(output, BUF_NAME, header, { prefix = "JjLog" })
  end

  vim.api.nvim_buf_set_var(bufnr, "jj_log_limit", opts.limit or 0)
  vim.api.nvim_buf_set_var(bufnr, "jj_log_template", opts.template)
  local rev_lines = set_rev_lines(bufnr, line_rev_ids, #header)

  setup_keymaps(bufnr)

  if not existing then
    ui.ensure_visible(bufnr)
  end

  -- Position cursor on first commit line
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for i = 1, #lines do
    if rev_lines[tostring(i)] then
      pcall(vim.api.nvim_win_set_cursor, 0, { i, 0 })
      break
    end
  end

  ui.set_statusline(bufnr, "jj-log")
end

return M
