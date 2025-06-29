local M = {}

-- Cache for command help parsing results
local help_cache = {}
local cache_ttl = 300 -- 5 minutes cache TTL

-- Parse jj help output to extract commands
local function parse_jj_commands()
  local cache_key = "jj_commands"
  local now = os.time()

  -- Check cache first
  if help_cache[cache_key] and help_cache[cache_key].timestamp + cache_ttl > now then
    return help_cache[cache_key].data
  end

  local help_output = vim.fn.system({ "jj", "--help" })
  if vim.v.shell_error ~= 0 then
    return {}
  end

  local commands = {}
  local in_commands_section = false

  for line in help_output:gmatch("[^\r\n]+") do
    -- Look for the Commands section
    if line:match("^Commands:") or line:match("^COMMANDS:") then
      in_commands_section = true
    elseif line:match("^Options:") or line:match("^OPTIONS:") or line:match("^Usage:") then
      in_commands_section = false
    elseif in_commands_section then
      -- Parse command lines that start with whitespace followed by a command name
      local cmd = line:match("^%s+([a-z][a-z0-9%-]*)")
      if cmd then
        table.insert(commands, cmd)
      end
    end
  end

  -- Cache the result
  help_cache[cache_key] = {
    data = commands,
    timestamp = now,
  }

  return commands
end

-- Parse command-specific help to extract flags
local function parse_command_flags(command)
  local cache_key = "jj_" .. command .. "_flags"
  local now = os.time()

  -- Check cache first
  if help_cache[cache_key] and help_cache[cache_key].timestamp + cache_ttl > now then
    return help_cache[cache_key].data
  end

  local help_output = vim.fn.system({ "jj", command, "--help" })
  if vim.v.shell_error ~= 0 then
    return {}
  end

  local flags = {}
  local in_options_section = false

  for line in help_output:gmatch("[^\r\n]+") do
    -- Look for Options section
    if line:match("^Options:") or line:match("^OPTIONS:") then
      in_options_section = true
    elseif line:match("^Commands:") or line:match("^COMMANDS:") or line:match("^Usage:") then
      in_options_section = false
    elseif in_options_section then
      -- Parse flag lines
      -- Look for patterns like: "  -f, --flag" or "      --long-flag"
      local short_flag, long_flag = line:match("^%s*%-([a-zA-Z]),%s*%-%-([a-z][a-z0-9%-]*)")
      if short_flag and long_flag then
        table.insert(flags, "-" .. short_flag)
        table.insert(flags, "--" .. long_flag)
      else
        -- Look for long flags only: "      --flag"
        local flag = line:match("^%s*%-%-([a-z][a-z0-9%-]*)")
        if flag then
          table.insert(flags, "--" .. flag)
        else
          -- Look for short flags only: "  -f"
          local short = line:match("^%s*%-([a-zA-Z])%s")
          if short then
            table.insert(flags, "-" .. short)
          end
        end
      end
    end
  end

  -- Add common global flags that work with most commands
  local global_flags = {
    "--help",
    "-h",
    "--repository",
    "-R",
    "--at-operation",
    "--config-toml",
  }

  for _, flag in ipairs(global_flags) do
    if not vim.tbl_contains(flags, flag) then
      table.insert(flags, flag)
    end
  end

  -- Cache the result
  help_cache[cache_key] = {
    data = flags,
    timestamp = now,
  }

  return flags
end

-- Smart completion function that provides context-aware suggestions
function M.complete(arglead, cmdline, cursorpos) -- luacheck: ignore cursorpos
  -- Parse the command line to understand context
  local parts = vim.split(cmdline, "%s+")
  local completions = {}

  -- Remove the :J command itself
  if parts[1] == "J" then
    table.remove(parts, 1)
  end

  -- If no subcommand yet, or completing the first argument
  -- We complete commands if:
  -- 1. No parts yet (just typed ":J ")
  -- 2. One part and cursor is still on it (":J sta|" where | is cursor)
  -- 3. One empty part (from ":J " which creates { "" } after removing "J")
  if #parts == 0 or (#parts == 1 and (not cmdline:match("%s$") or parts[1] == "")) then
    -- Complete jj subcommands
    local commands = parse_jj_commands()
    for _, cmd in ipairs(commands) do
      if arglead == "" or cmd:find("^" .. vim.pesc(arglead)) then
        table.insert(completions, cmd)
      end
    end

    -- Also include our custom commands (prioritize status, diff, and log)
    local custom_commands = { "status", "diff", "log" }
    for _, cmd in ipairs(custom_commands) do
      if
        (arglead == "" or cmd:find("^" .. vim.pesc(arglead)))
        and not vim.tbl_contains(completions, cmd)
      then
        table.insert(completions, cmd)
      end
    end
  else
    -- We have a subcommand, complete flags for it
    local subcommand = parts[1]
    local flags = parse_command_flags(subcommand)

    -- Filter flags that haven't been used yet and match the current input
    local used_flags = {}
    for i = 2, #parts do
      if parts[i]:match("^%-") then
        used_flags[parts[i]] = true
      end
    end

    for _, flag in ipairs(flags) do
      if (arglead == "" or flag:find("^" .. vim.pesc(arglead))) and not used_flags[flag] then
        table.insert(completions, flag)
      end
    end

    -- If completing a value after certain flags, provide context-specific completions
    if #parts >= 2 then
      local prev_arg = parts[#parts - 1] or ""

      -- Branch/bookmark completions for relevant flags
      if prev_arg:match("^%-%-?[br]") or prev_arg == "--bookmark" or prev_arg == "--branch" then
        local bookmarks = M.get_bookmarks()
        for _, bookmark in ipairs(bookmarks) do
          if arglead == "" or bookmark:find("^" .. vim.pesc(arglead)) then
            table.insert(completions, bookmark)
          end
        end
      end

      -- File completions for certain commands
      if subcommand == "diff" or subcommand == "show" or subcommand == "file" then
        -- Add basic file completion (could be enhanced with actual file listing)
        local files = M.get_changed_files()
        for _, file in ipairs(files) do
          if arglead == "" or file:find("^" .. vim.pesc(arglead)) then
            table.insert(completions, file)
          end
        end
      end
    end
  end

  -- Sort completions for better user experience
  table.sort(completions)

  return completions
end

-- Get list of bookmarks for completion
function M.get_bookmarks()
  local result = vim.fn.system({ "jj", "bookmark", "list" })
  if vim.v.shell_error ~= 0 then
    return {}
  end

  local bookmarks = {}
  for line in result:gmatch("[^\r\n]+") do
    -- Parse bookmark names from output like "main: abc123"
    local bookmark = line:match("^([^:]+):")
    if bookmark then
      bookmark = bookmark:match("^%s*(.-)%s*$") -- trim whitespace
      if bookmark ~= "" then
        table.insert(bookmarks, bookmark)
      end
    end
  end

  return bookmarks
end

-- Get list of changed files for completion
function M.get_changed_files()
  local result = vim.fn.system({ "jj", "status" })
  if vim.v.shell_error ~= 0 then
    return {}
  end

  local files = {}
  local in_changes = false

  for line in result:gmatch("[^\r\n]+") do
    if line:match("^Working copy changes:") then
      in_changes = true
    elseif line:match("^Working copy") or line:match("^Parent commit") then
      in_changes = false
    elseif in_changes and line:match("^[A-Z]") then
      local filename = line:match("^[A-Z] (.+)")
      if filename then
        table.insert(files, filename)
      end
    end
  end

  return files
end

-- Clear the help cache (useful for testing or if jj is updated)
function M.clear_cache()
  help_cache = {}
end

return M
