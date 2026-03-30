local M = {}

--- Parse the Commands: section from jj help output.
local function parse_commands(args)
  local output = vim.fn.system(args)
  if vim.v.shell_error ~= 0 then
    return {}
  end

  local commands = {}
  local in_commands = false

  for line in output:gmatch("[^\r\n]+") do
    if line:match("^Commands:") or line:match("^COMMANDS:") then
      in_commands = true
    elseif in_commands then
      if line:match("^%S") then
        break
      end
      local cmd = line:match("^%s+([a-z][a-z0-9%-]*)")
      if cmd then
        table.insert(commands, cmd)
      end
    end
  end

  return commands
end

--- Cached user aliases (parsed once per session).
local cached_aliases = nil
local function get_aliases()
  if cached_aliases then
    return cached_aliases
  end
  cached_aliases = {}
  local output = vim.fn.system({ "jj", "config", "list", "aliases" })
  if vim.v.shell_error == 0 and output then
    for alias in output:gmatch("aliases%.([%w_-]+)") do
      table.insert(cached_aliases, alias)
    end
  end
  return cached_aliases
end

--- Get bookmarks and recent change IDs for revision completion.
local function get_revisions()
  local revisions = { "@", "@-", "@+", "root()" }
  local init = require("jj-fugitive")

  -- Add bookmarks
  local bl = init.run_jj({ "bookmark", "list", "--no-remote", "-T", 'name ++ "\n"' })
  if bl then
    for name in bl:gmatch("[^\n]+") do
      if name:match("%S") then
        table.insert(revisions, name)
      end
    end
  end

  -- Add recent change IDs
  local log =
    init.run_jj({ "log", "--no-graph", "--limit", "20", "-T", 'change_id.short() ++ "\n"' })
  if log then
    for id in log:gmatch("[^\n]+") do
      if id:match("%S") then
        table.insert(revisions, id)
      end
    end
  end

  return revisions
end

--- Commands known to have subcommands.
local COMMANDS_WITH_SUBS = {
  "git",
  "bookmark",
  "config",
  "operation",
  "op",
  "workspace",
  "file",
}

--- Smart completion for :J command.
function M.complete(arglead, cmdline, _)
  local parts = vim.split(cmdline, "%s+")
  if parts[1] == "J" then
    table.remove(parts, 1)
  end

  -- Filter empties
  local filtered = {}
  for _, p in ipairs(parts) do
    if p ~= "" then
      table.insert(filtered, p)
    end
  end
  parts = filtered

  local completions = {}

  -- Completing first argument (command name)
  if #parts == 0 or (#parts == 1 and not cmdline:match("%s$")) then
    local commands = parse_commands({ "jj", "--help" })
    -- Add our custom commands that might not be in jj help
    local custom = { "status", "diff", "log", "browse", "bookmark", "push", "fetch" }
    for _, c in ipairs(custom) do
      if not vim.tbl_contains(commands, c) then
        table.insert(commands, c)
      end
    end

    -- Add user aliases from jj config (cached)
    for _, alias in ipairs(get_aliases()) do
      if not vim.tbl_contains(commands, alias) then
        table.insert(commands, alias)
      end
    end

    for _, cmd in ipairs(commands) do
      if arglead == "" or cmd:find("^" .. vim.pesc(arglead)) then
        table.insert(completions, cmd)
      end
    end
  else
    local main_cmd = parts[1]

    -- Check if previous arg is -r (revision flag) — complete with revisions
    local prev = parts[#parts - (cmdline:match("%s$") and 0 or 1)]
    if
      prev == "-r"
      or prev == "--revision"
      or prev == "--into"
      or prev == "--from"
      or prev == "--to"
    then
      for _, rev in ipairs(get_revisions()) do
        if arglead == "" or rev:find("^" .. vim.pesc(arglead)) then
          table.insert(completions, rev)
        end
      end
    -- Completing subcommand for commands that have them
    elseif
      vim.tbl_contains(COMMANDS_WITH_SUBS, main_cmd)
      and (#parts == 1 and cmdline:match("%s$") or (#parts == 2 and not cmdline:match("%s$")))
    then
      local subs = parse_commands({ "jj", main_cmd, "--help" })
      for _, sub in ipairs(subs) do
        if arglead == "" or sub:find("^" .. vim.pesc(arglead)) then
          table.insert(completions, sub)
        end
      end
    end
  end

  table.sort(completions)
  return completions
end

return M
