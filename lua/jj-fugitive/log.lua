local M = {}

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
  if not marked_output and effective_template ~= DEFAULT_LOG_TEMPLATE then
    -- User template may be invalid — fall back to builtin
    effective_template = DEFAULT_LOG_TEMPLATE
    marked_template = '"'
      .. LOG_REV_MARKER
      .. '" ++ stringify(commit_id.short()) ++ ">" ++ ('
      .. effective_template
      .. ")"
    marked_output = init.run_jj(build_log_args(opts, marked_template))
  end
  if not marked_output then
    return nil
  end

  local visible_output, line_rev_ids = extract_log_metadata(marked_output)
  return visible_output, line_rev_ids, effective_template
end

--- Check if a revision is divergent.
local function is_divergent(rev)
  local init = require("jj-fugitive")
  local out = init.run_jj({ "log", "-r", rev, "--no-graph", "-T", "divergent" })
  return out and out:match("true")
end

local function warn_divergent(rev)
  if is_divergent(rev) then
    require("jj-fugitive.ui").warn(
      "Revision " .. rev .. " is divergent — resolve divergence first"
    )
    return true
  end
  return false
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
      require("jj-fugitive.ui").info(msg)
    end
    init.refresh_views()
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
  local ui = require("jj-fugitive.ui")
  local current = ui.file_at_rev(filename, rev)
  local parent = ui.file_at_rev(filename, rev .. "-")

  ui.open_sidebyside(
    parent,
    filename .. " (" .. rev .. "-)",
    current,
    filename .. " (" .. rev .. ")",
    filename,
    { repo_root = require("jj-fugitive").repo_root() }
  )
end

--- Setup keymaps for a detail buffer (show/diff opened from log).
function M.setup_detail_keymaps(bufnr, kind, id)
  local ui = require("jj-fugitive.ui")

  local init = require("jj-fugitive")
  if init.review_config then
    local review_ctx = { rev = id }
    ui.map(bufnr, "n", "cR", function()
      require("redline").comment_unified_diff(init.review_config, bufnr, review_ctx)
    end)
  end

  -- Side-by-side diff (available in both show and diff views)
  ui.map(bufnr, "n", "D", function()
    local files_output = require("jj-fugitive").run_jj({ "diff", "--name-only", "-r", id })
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
      ui.warn("No files changed")
      return
    end

    if #files == 1 then
      sidebyside_at_rev(files[1], id)
      return
    end

    ui.select(files, "Side-by-side diff for", function(choice)
      if choice then
        sidebyside_at_rev(choice, id)
      end
    end)
  end)

  ui.setup_view_keymaps(bufnr, {
    log = function()
      vim.cmd(ui.close_cmd())
      require("jj-fugitive.log").show()
    end,
    status = function()
      vim.cmd(ui.close_cmd())
      require("jj-fugitive.status").show()
    end,
    bookmark = function()
      vim.cmd(ui.close_cmd())
      require("jj-fugitive.bookmark").show()
    end,
    review = init.review_config and function()
      require("redline").show(init.review_config)
    end,
    help = function()
      ui.help_popup("jj-fugitive " .. kind, {
        kind .. " for commit " .. id,
        "",
        "Actions:",
        "  cR      Add review comment",
        "  gR      Open review buffer",
        "  D       Side-by-side diff (pick file)",
        "",
        "Views:",
        "  gb      Switch to bookmark view",
        "  gl      Switch to log view",
        "  gs      Switch to status view",
        "",
        "Other:",
        "  q       Close",
        "  g?      This help",
      })
    end,
  })
end

--- Setup keymaps for the log buffer (idempotent — safe to call on refresh).
local function setup_keymaps(bufnr)
  local ui = require("jj-fugitive.ui")
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
    ui.info(
      "Log layout: " .. (next_template == COMFORTABLE_LOG_TEMPLATE and "comfortable" or "compact")
    )
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
    local ansi = require("fugitive-core.ansi")
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
    require("jj-fugitive.diff").show({ rev = id })
  end)

  -- Edit at commit
  ui.map(bufnr, "n", "e", function()
    local id = get_rev_id()
    if id and not warn_divergent(id) then
      run_and_refresh({ "edit", id }, "Editing at " .. id)
    end
  end)

  -- New commit after this one
  ui.map(bufnr, "n", "n", function()
    local id = get_rev_id()
    if id and not warn_divergent(id) then
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
    if warn_divergent(id) or warn_divergent(source) then
      return
    end
    local label = rev_label(id)
    if ui.confirm("Squash " .. source .. " into " .. label) then
      run_and_refresh(
        { "squash", "-r", source, "--into", id },
        "Squashed " .. source .. " into " .. label
      )
    end
  end)

  -- Squash prompted source into cursor (lowercase = prompt source, cursor is dest)
  ui.map(bufnr, "n", "gqs", function()
    local id = get_rev_id()
    if not id or warn_divergent(id) then
      return
    end
    local label = rev_label(id)
    ui.input("Squash into " .. label .. " from", function(source)
      if source and source ~= "" then
        if ui.confirm("Squash " .. source .. " into " .. label) then
          run_and_refresh(
            { "squash", "-r", source, "--into", id },
            "Squashed " .. source .. " into " .. label
          )
        end
      end
    end)
  end)

  -- Squash cursor into prompted destination (uppercase = cursor is source)
  ui.map(bufnr, "n", "gqS", function()
    local id = get_rev_id()
    if not id or warn_divergent(id) then
      return
    end
    local label = rev_label(id)
    ui.input("Squash " .. label .. " into", function(into)
      if into and into ~= "" then
        if ui.confirm("Squash " .. label .. " into " .. into) then
          run_and_refresh(
            { "squash", "-r", id, "--into", into },
            "Squashed " .. label .. " into " .. into
          )
        end
      end
    end)
  end)

  -- Abandon commit
  ui.map(bufnr, "n", "A", function()
    local id = get_rev_id()
    if id and ui.confirm("Abandon " .. rev_label(id)) then
      run_and_refresh({ "abandon", id }, "Abandoned " .. id)
    end
  end)

  -- Bookmark mode
  ui.map(bufnr, "n", "b", function()
    local id = get_rev_id()
    if not id or warn_divergent(id) then
      return
    end
    ui.input("Bookmark name (create/move to " .. id .. ")", function(name)
      if name and name ~= "" then
        -- Try set first (moves existing), fall back to create
        local init = require("jj-fugitive")
        local result = init.run_jj({ "bookmark", "set", name, "-r", id, "--allow-backwards" })
        if not result then
          result = init.run_jj({ "bookmark", "create", name, "-r", id })
        end
        if result then
          ui.info("Bookmark '" .. name .. "' -> " .. id)
          init.refresh_views()
        end
      end
    end)
  end)

  -- Rebase helpers: lowercase prompts source, uppercase uses cursor as source.
  ui.map(bufnr, "n", "rw", function()
    local id = get_rev_id()
    if not id then
      return
    end
    local source = working_copy_source()
    if warn_divergent(id) or warn_divergent(source) then
      return
    end
    local label = rev_label(id)
    if ui.confirm("Rebase " .. source .. " onto " .. label) then
      run_and_refresh(
        { "rebase", "-r", source, "-d", id },
        "Rebased " .. source .. " onto " .. label
      )
    end
  end)

  ui.map(bufnr, "n", "rs", function()
    local id = get_rev_id()
    if not id or warn_divergent(id) then
      return
    end
    local label = rev_label(id)
    ui.input("Rebase onto " .. label .. " from", function(source)
      if source and source ~= "" then
        if ui.confirm("Rebase " .. source .. " onto " .. label) then
          run_and_refresh(
            { "rebase", "-s", source, "-d", id },
            "Rebased " .. source .. " onto " .. label
          )
        end
      end
    end)
  end)

  ui.map(bufnr, "n", "rS", function()
    local id = get_rev_id()
    if not id or warn_divergent(id) then
      return
    end
    local label = rev_label(id)
    ui.input("Rebase " .. label .. " onto", function(dest)
      if dest and dest ~= "" then
        if ui.confirm("Rebase " .. label .. " and descendants onto " .. dest) then
          run_and_refresh(
            { "rebase", "-s", id, "-d", dest },
            "Rebased " .. label .. " and descendants onto " .. dest
          )
        end
      end
    end)
  end)

  ui.map(bufnr, "n", "rb", function()
    local id = get_rev_id()
    if not id or warn_divergent(id) then
      return
    end
    local label = rev_label(id)
    ui.input("Rebase branch onto " .. label .. " from", function(branch)
      if branch and branch ~= "" then
        if ui.confirm("Rebase branch " .. branch .. " onto " .. label) then
          run_and_refresh(
            { "rebase", "-b", branch, "-d", id },
            "Rebased branch " .. branch .. " onto " .. label
          )
        end
      end
    end)
  end)

  -- Rebase cursor's branch onto prompted destination
  ui.map(bufnr, "n", "rB", function()
    local id = get_rev_id()
    if not id or warn_divergent(id) then
      return
    end
    local label = rev_label(id)
    ui.input("Rebase branch of " .. label .. " onto", function(dest)
      if dest and dest ~= "" then
        if ui.confirm("Rebase branch of " .. label .. " onto " .. dest) then
          run_and_refresh(
            { "rebase", "-b", id, "-d", dest },
            "Rebased branch of " .. label .. " onto " .. dest
          )
        end
      end
    end)
  end)

  -- Rebase single revision (children stay) onto cursor
  ui.map(bufnr, "n", "rr", function()
    local id = get_rev_id()
    if not id or warn_divergent(id) then
      return
    end
    local label = rev_label(id)
    ui.input("Rebase onto " .. label .. " rev", function(rev)
      if rev and rev ~= "" then
        if ui.confirm("Rebase " .. rev .. " onto " .. label) then
          run_and_refresh({ "rebase", "-r", rev, "-d", id }, "Rebased " .. rev .. " onto " .. label)
        end
      end
    end)
  end)

  -- Extract cursor revision and move it elsewhere
  ui.map(bufnr, "n", "rR", function()
    local id = get_rev_id()
    if not id or warn_divergent(id) then
      return
    end
    local label = rev_label(id)
    ui.input("Extract " .. label .. " onto", function(dest)
      if dest and dest ~= "" then
        if ui.confirm("Extract " .. label .. " onto " .. dest) then
          run_and_refresh(
            { "rebase", "-r", id, "-d", dest },
            "Extracted " .. label .. " onto " .. dest
          )
        end
      end
    end)
  end)

  -- Insert revision after cursor in stack
  ui.map(bufnr, "n", "ra", function()
    local id = get_rev_id()
    if not id or warn_divergent(id) then
      return
    end
    local label = rev_label(id)
    ui.input("Insert after " .. label .. " rev", function(rev)
      if rev and rev ~= "" then
        if ui.confirm("Insert " .. rev .. " after " .. label) then
          run_and_refresh(
            { "rebase", "-r", rev, "--after", id },
            "Inserted " .. rev .. " after " .. label
          )
        end
      end
    end)
  end)

  -- Move cursor revision after another revision in stack
  ui.map(bufnr, "n", "rA", function()
    local id = get_rev_id()
    if not id or warn_divergent(id) then
      return
    end
    local label = rev_label(id)
    ui.input("Insert " .. label .. " after", function(dest)
      if dest and dest ~= "" then
        if ui.confirm("Insert " .. label .. " after " .. dest) then
          run_and_refresh(
            { "rebase", "-r", id, "--after", dest },
            "Inserted " .. label .. " after " .. dest
          )
        end
      end
    end)
  end)

  -- Block built-in keys that error on read-only buffer
  -- Mapping to a function (not <Nop>) lets Neovim still wait for multi-key sequences
  ui.map(bufnr, "n", "c", function() end)

  -- Describe (cc like fugitive's commit)
  ui.map(bufnr, "n", "cc", function()
    local id = get_rev_id()
    if id and not warn_divergent(id) then
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

  ui.map(bufnr, "n", "gu", function()
    require("jj-fugitive").undo()
  end)

  -- Show aliases
  ui.map(bufnr, "n", "ga", function()
    ui.show_aliases()
  end)

  local init = require("jj-fugitive")
  ui.setup_view_keymaps(bufnr, {
    status = function()
      vim.cmd(ui.close_cmd())
      require("jj-fugitive.status").show()
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
        "  rw        Rebase @/@- onto cursor (children stay)",
        "  rs        Rebase prompted source+desc onto cursor",
        "  rS        Rebase cursor+desc onto prompted destination",
        "  rr        Rebase prompted revision onto cursor (children stay)",
        "  rR        Rebase cursor onto prompted destination (children stay)",
        "  rb        Rebase prompted branch onto cursor",
        "  rB        Rebase cursor branch onto prompted destination",
        "  ra        Insert prompted revision after cursor",
        "  rA        Insert cursor after prompted destination",
        "",
        "Squash:",
        "  gqw       Squash @/@- into cursor",
        "  gqs       Squash prompted revision into cursor",
        "  gqS       Squash cursor into prompted revision",
        "",
        "Views:",
        "  gb        Switch to bookmark view",
        "  gC        Toggle compact/comfortable log layout",
        "  gR        Open review buffer",
        "  gs        Switch to status view",
        "",
        "Other:",
        "  ga        Show jj aliases",
        "  gu        Undo last jj operation",
        "  R         Refresh",
        "  q         Close",
        "  g?        This help",
      }, { width = 68 })
    end,
  })
end

--- Check if a log buffer exists.
function M.is_open()
  return require("jj-fugitive.ui").find_buf(BUF_PATTERN) ~= nil
end

--- Refresh the current log view.
function M.refresh()
  rev_label_cache = {}
  local ui = require("jj-fugitive.ui")
  local ansi = require("fugitive-core.ansi")
  local bufnr = ui.find_buf(BUF_PATTERN)
  if not bufnr then
    return
  end

  local view = ui.save_view(bufnr)

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

  ui.restore_view(bufnr, view)
end

--- Show the log view.
function M.show(opts)
  opts = opts or {}
  rev_label_cache = {}

  local ui = require("jj-fugitive.ui")
  local ansi = require("fugitive-core.ansi")

  local output, line_rev_ids, effective_template = get_log(opts)
  if not output then
    return
  end

  if not has_commits(line_rev_ids) then
    ui.warn("No commits found")
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
  vim.api.nvim_buf_set_var(bufnr, "jj_log_template", effective_template)
  local rev_lines = set_rev_lines(bufnr, line_rev_ids, #header)

  setup_keymaps(bufnr)

  ui.ensure_visible(bufnr)

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
