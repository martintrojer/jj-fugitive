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
    local custom = { "status", "diff", "log", "browse", "bookmark" }
    for _, c in ipairs(custom) do
      if not vim.tbl_contains(commands, c) then
        table.insert(commands, c)
      end
    end

    -- Add user aliases from jj config
    local alias_output = vim.fn.system({ "jj", "config", "list", "aliases" })
    if vim.v.shell_error == 0 and alias_output then
      for alias in alias_output:gmatch("aliases%.([%w_-]+)") do
        if not vim.tbl_contains(commands, alias) then
          table.insert(commands, alias)
        end
      end
    end

    for _, cmd in ipairs(commands) do
      if arglead == "" or cmd:find("^" .. vim.pesc(arglead)) then
        table.insert(completions, cmd)
      end
    end
  else
    local main_cmd = parts[1]

    -- Completing subcommand for commands that have them
    if
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
