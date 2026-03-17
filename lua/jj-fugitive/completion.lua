local M = {}

-- Cache for command help parsing results
local help_cache = {}
local CACHE_TTL = 300 -- 5 minutes cache TTL

-- Helper to trim whitespace
local function trim(str)
  return str:gsub("^%s*", ""):gsub("%s*$", "")
end

-- Common help parsing framework
-- command_args: table of command arguments (e.g., {"jj", "--help"})
-- cache_key: string key for caching
-- section_type: "commands" or "options"
-- parse_line_fn: function(line) -> item or table of items or nil
-- fallback_data: optional fallback data if parsing fails
local function parse_help_output(
  command_args,
  cache_key,
  section_type,
  parse_line_fn,
  fallback_data
)
  local now = os.time()

  -- Check cache first
  if help_cache[cache_key] and help_cache[cache_key].timestamp + CACHE_TTL > now then
    return help_cache[cache_key].data
  end

  local help_output = vim.fn.system(command_args)
  if vim.v.shell_error ~= 0 then
    -- Return fallback data if provided
    if fallback_data then
      return fallback_data
    end
    return {}
  end

  local results = {}
  local in_target_section = false
  local section_start_pattern = section_type == "commands" and "^Commands:" or "^Options:"
  local section_end_patterns = {
    "^Options:",
    "^OPTIONS:",
    "^Commands:",
    "^COMMANDS:",
    "^Usage:",
  }

  for line in help_output:gmatch("[^\r\n]+") do
    -- Look for target section
    if line:match(section_start_pattern) or line:match("^" .. section_type:upper() .. ":") then
      in_target_section = true
    else
      -- Check if we've hit an end pattern
      for _, pattern in ipairs(section_end_patterns) do
        if line:match(pattern) and not line:match(section_start_pattern) then
          in_target_section = false
          break
        end
      end
    end

    if in_target_section then
      local item = parse_line_fn(line)
      if item then
        -- Handle both single items and arrays of items (for flags with multiple per line)
        if type(item) == "table" and item[1] and type(item[1]) == "table" and item[1].name then
          -- Array of items
          for _, sub_item in ipairs(item) do
            table.insert(results, sub_item)
          end
        else
          -- Single item
          table.insert(results, item)
        end
      end
    end
  end

  -- Cache the result
  help_cache[cache_key] = {
    data = results,
    timestamp = now,
  }

  return results
end

-- Parse jj help output to extract commands with descriptions
local function parse_jj_commands()
  local function parse_command_line(line)
    -- Parse command lines with descriptions
    -- Format: "  command    Description of the command"
    local cmd, desc = line:match("^%s+([a-z][a-z0-9%-]*)%s+(.+)")
    if cmd and desc then
      return { name = cmd, description = trim(desc) }
    else
      -- Fallback: just the command name
      local cmd_only = line:match("^%s+([a-z][a-z0-9%-]*)")
      if cmd_only then
        return { name = cmd_only, description = "" }
      end
    end
    return nil
  end

  return parse_help_output({ "jj", "--help" }, "jj_commands", "commands", parse_command_line, nil)
end

-- Parse subcommands for commands that have them (like 'git', 'bookmark', etc.)
local function parse_subcommands(command)
  local cache_key = "jj_" .. command .. "_subcommands"

  -- Fallback for environments where help parsing might fail
  local fallback_subcommands = {
    bookmark = { "create", "delete", "list", "set", "move", "rename", "track", "untrack" },
    git = { "push", "fetch", "pull", "clone", "remote", "import", "export" },
    branch = { "create", "delete", "list", "set" },
    config = { "get", "set", "list", "unset" },
    operation = { "log", "undo", "restore", "abandon" },
    op = { "log", "undo", "restore", "abandon" },
    workspace = { "add", "forget", "list", "root" },
  }

  local fallback_data = nil
  if fallback_subcommands[command] then
    fallback_data = {}
    for _, subcmd in ipairs(fallback_subcommands[command]) do
      table.insert(fallback_data, { name = subcmd, description = "" })
    end
  end

  -- Split command into parts for proper argument passing
  local command_parts = vim.split(command, "%s+")
  local args = { "jj" }
  for _, part in ipairs(command_parts) do
    table.insert(args, part)
  end
  table.insert(args, "--help")

  local function parse_subcommand_line(line)
    -- Parse subcommand lines with descriptions
    local subcmd, desc = line:match("^%s+([a-z][a-z0-9%-]*)%s+(.+)")
    if subcmd and desc then
      return { name = subcmd, description = trim(desc) }
    else
      -- Fallback: just the subcommand name
      local subcmd_only = line:match("^%s+([a-z][a-z0-9%-]*)")
      if subcmd_only then
        return { name = subcmd_only, description = "" }
      end
    end
    return nil
  end

  return parse_help_output(args, cache_key, "commands", parse_subcommand_line, fallback_data)
end

-- Parse command-specific help to extract flags with descriptions
local function parse_command_flags(command)
  local cache_key = "jj_" .. command .. "_flags"

  -- Fallback for environments where help parsing might fail
  local fallback_flags = {
    { name = "--help", description = "Print help" },
    { name = "-h", description = "Print help" },
  }

  -- Split command into parts for proper argument passing
  local command_parts = vim.split(command, "%s+")
  local args = { "jj" }
  for _, part in ipairs(command_parts) do
    table.insert(args, part)
  end
  table.insert(args, "--help")

  local function parse_flag_line(line)
    -- Parse flag lines with descriptions
    -- Look for patterns like: "  -h, --help" (flags on one line)
    local short_flag, long_flag = line:match("^%s*%-([a-zA-Z]),%s*%-%-([a-z][a-z0-9%-]*)")
    if short_flag and long_flag then
      -- This is a flag line, description might be on next line or same line
      local desc = line:match("^%s*%-[a-zA-Z],%s*%-%-[a-z][a-z0-9%-]*%s+(.+)")
      if not desc then
        desc = "Print help information" -- Default for help flags
      end
      -- Return both flags as separate items (need special handling)
      return {
        { name = "-" .. short_flag, description = desc },
        { name = "--" .. long_flag, description = desc },
      }
    else
      -- Look for long flags only: "      --flag"
      local flag = line:match("^%s*%-%-([a-z][a-z0-9%-]*)")
      if flag then
        local desc = line:match("^%s*%-%-[a-z][a-z0-9%-]*%s+(.+)")
        if not desc then
          desc = "" -- No description found
        end
        return { { name = "--" .. flag, description = desc } }
      else
        -- Look for short flags only: "  -f"
        local short = line:match("^%s*%-([a-zA-Z])%s")
        if short then
          local desc = line:match("^%s*%-[a-zA-Z]%s+(.+)")
          if not desc then
            desc = ""
          end
          return { { name = "-" .. short, description = desc } }
        end
      end
    end
    return nil
  end

  -- Use the framework (it handles multiple flags per line automatically)
  local flags = parse_help_output(args, cache_key, "options", parse_flag_line, fallback_flags)

  -- Add common global flags that work with most commands
  local global_flags = {
    { name = "--help", description = "Print help information" },
    { name = "-h", description = "Print help information" },
    { name = "--repository", description = "Path to repository to operate on" },
    { name = "-R", description = "Path to repository to operate on" },
    { name = "--at-operation", description = "Operation to load the repo at" },
    { name = "--config-toml", description = "Additional configuration options" },
  }

  for _, global_flag in ipairs(global_flags) do
    local already_exists = false
    for _, existing_flag in ipairs(flags) do
      if existing_flag.name == global_flag.name then
        already_exists = true
        break
      end
    end
    if not already_exists then
      table.insert(flags, global_flag)
    end
  end

  -- Update cache with final results
  help_cache[cache_key] = {
    data = flags,
    timestamp = os.time(),
  }

  return flags
end

-- Commands that have subcommands
local commands_with_subcommands = {
  "git",
  "bookmark",
  "branch",
  "config",
  "operation",
  "op",
  "workspace",
}

-- Check if a command has subcommands
local function has_subcommands(command)
  return vim.tbl_contains(commands_with_subcommands, command)
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

  -- Remove empty parts that can be created by trailing spaces
  local filtered_parts = {}
  for _, part in ipairs(parts) do
    if part ~= "" then
      table.insert(filtered_parts, part)
    end
  end
  parts = filtered_parts

  -- If no subcommand yet, or completing the first argument
  if #parts == 0 or (#parts == 1 and (not cmdline:match("%s$") or parts[1] == "")) then
    -- Complete jj main commands
    local commands = parse_jj_commands()
    for _, cmd in ipairs(commands) do
      local cmd_name = type(cmd) == "table" and cmd.name or cmd
      if arglead == "" or cmd_name:find("^" .. vim.pesc(arglead)) then
        table.insert(completions, cmd_name)
      end
    end

    -- Also include our custom commands (prioritize status, diff, and log)
    local custom_commands = { "status", "diff", "log", "browse" }
    for _, cmd in ipairs(custom_commands) do
      if
        (arglead == "" or cmd:find("^" .. vim.pesc(arglead)))
        and not vim.tbl_contains(completions, cmd)
      then
        table.insert(completions, cmd)
      end
    end
  else
    -- We have at least one argument
    local main_command = parts[1]

    -- Case 1: Command has subcommands and we're completing the second argument
    -- This happens when: ":J git " (1 part + trailing space) or ":J git fe" (2 parts, no trailing space)
    if
      has_subcommands(main_command)
      and (#parts == 1 and cmdline:match("%s$") or (#parts == 2 and not cmdline:match("%s$")))
    then
      -- Complete subcommands for commands like 'git', 'bookmark', etc.
      local subcommands = parse_subcommands(main_command)
      for _, subcmd in ipairs(subcommands) do
        local subcmd_name = type(subcmd) == "table" and subcmd.name or subcmd
        if arglead == "" or subcmd_name:find("^" .. vim.pesc(arglead)) then
          table.insert(completions, subcmd_name)
        end
      end
    else
      -- Case 2: Complete flags for the command (or subcommand)
      local command_for_flags = main_command

      -- If we have a subcommand, use it for flag completion
      if has_subcommands(main_command) and #parts >= 2 then
        command_for_flags = main_command .. " " .. parts[2]
      end

      local flags = parse_command_flags(command_for_flags)

      -- Filter flags that haven't been used yet and match the current input
      local used_flags = {}
      local start_index = has_subcommands(main_command) and #parts >= 2 and 3 or 2
      for i = start_index, #parts do
        if parts[i] and parts[i]:match("^%-") then
          used_flags[parts[i]] = true
        end
      end

      for _, flag in ipairs(flags) do
        local flag_name = type(flag) == "table" and flag.name or flag
        if
          (arglead == "" or flag_name:find("^" .. vim.pesc(arglead))) and not used_flags[flag_name]
        then
          table.insert(completions, flag_name)
        end
      end

      -- Case 3: Context-specific completions
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
        local effective_command = has_subcommands(main_command) and parts[2] or main_command
        if
          effective_command == "diff"
          or effective_command == "show"
          or effective_command == "file"
        then
          local files = M.get_changed_files()
          for _, file in ipairs(files) do
            if arglead == "" or file:find("^" .. vim.pesc(arglead)) then
              table.insert(completions, file)
            end
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
  local init = require("jj-fugitive.init")
  local result = init.run_jj({ "bookmark", "list" })
  if not result then
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
  local init = require("jj-fugitive.init")
  local result = init.run_jj({ "status" })
  if not result then
    return {}
  end

  local files = {}
  local in_changes = false

  for line in result:gmatch("[^\r\n]+") do
    if line:match("^Working copy changes:") then
      in_changes = true
    elseif line:match("^Working copy") or line:match("^Parent commit") then
      in_changes = false
    elseif in_changes and line:match("^[A-Z] ") then
      local filename = line:match("^[A-Z] (.+)")
      if filename then
        table.insert(files, filename)
      end
    end
  end

  return files
end

-- Get help information for a command
function M.get_command_help(command)
  local commands = parse_jj_commands()
  for _, cmd in ipairs(commands) do
    if type(cmd) == "table" and cmd.name == command then
      return cmd.description
    end
  end
  return ""
end

-- Get help information for a flag
function M.get_flag_help(command, flag)
  local flags = parse_command_flags(command)
  for _, flag_info in ipairs(flags) do
    if type(flag_info) == "table" and flag_info.name == flag then
      return flag_info.description
    end
  end
  return ""
end

-- Clear the help cache (useful for testing or if jj is updated)
function M.clear_cache()
  help_cache = {}
end

-- Alias for the complete function for testing compatibility
function M.complete_jj_command(arglead, cmdline, cursorpos)
  return M.complete(arglead, cmdline, cursorpos)
end

return M
