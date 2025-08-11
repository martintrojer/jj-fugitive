local M = {}

-- Cache for repository roots to avoid repeated filesystem traversal
local repo_root_cache = {}

-- Find the jj repository root starting from a given directory
local function find_jj_root(start_path)
  -- Normalize the cache key to an absolute path without trailing slash
  local key = vim.fn.fnamemodify(start_path or vim.fn.getcwd(), ":p")
  if key:sub(-1) == "/" and key ~= "/" then
    key = key:sub(1, -2)
  end

  -- Check cache first (positive or negative)
  if repo_root_cache[key] ~= nil then
    return repo_root_cache[key] or nil
  end

  -- Walk up the directory tree looking for .jj directory using a normalized path
  local path = key

  -- Walk up the directory tree looking for .jj directory
  while path ~= "/" and path ~= "" do
    local jj_dir = path .. "/.jj"
    if vim.fn.isdirectory(jj_dir) == 1 then
      repo_root_cache[key] = path
      return path
    end

    -- Go up one directory
    local parent = vim.fn.fnamemodify(path, ":h")
    if parent == path then
      break -- Reached root
    end
    path = parent
  end

  -- Cache negative result (nil) as false to distinguish from uncached
  repo_root_cache[key] = false
  return nil
end

-- Get the repository root, trying current buffer's directory first, then cwd
local function get_repo_root()
  -- First try the directory of the current buffer
  local current_file = vim.api.nvim_buf_get_name(0)
  if current_file ~= "" then
    local file_dir = vim.fn.fnamemodify(current_file, ":p:h")
    local repo_root = find_jj_root(file_dir)
    if repo_root then
      return repo_root
    end
  end

  -- Fall back to current working directory
  return find_jj_root(vim.fn.getcwd())
end

local function run_jj_command(args, options)
  options = options or {} -- luacheck: ignore options

  -- Find the repository root
  local repo_root = get_repo_root()
  if not repo_root then
    vim.api.nvim_err_writeln("Not in a jj repository. Current directory: " .. vim.fn.getcwd())
    return nil
  end

  local cmd = { "jj" }
  if type(args) == "string" and args ~= "" then
    for arg in args:gmatch("%S+") do
      table.insert(cmd, arg)
    end
  elseif type(args) == "table" then
    for _, arg in ipairs(args) do
      table.insert(cmd, arg)
    end
  end

  -- Run the command from the repository root
  -- Use local-directory change to avoid affecting other windows/tabs
  local old_cwd = vim.fn.getcwd()
  local success = pcall(vim.cmd, "lcd " .. vim.fn.fnameescape(repo_root))
  if not success then
    vim.api.nvim_err_writeln("Failed to change to repository root: " .. repo_root)
    return nil
  end

  local result = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error

  -- Restore original working directory
  pcall(vim.cmd, "lcd " .. vim.fn.fnameescape(old_cwd))

  if exit_code ~= 0 then
    vim.api.nvim_err_writeln("jj command failed: " .. result)
    return nil
  end
  return result, repo_root
end

-- Helper function to check if a flag is present in command parts
local function has_flag(cmd_parts, flag_pattern)
  for _, part in ipairs(cmd_parts) do
    if part == flag_pattern or part:match("^" .. flag_pattern .. "=") then
      return true
    end
    -- Handle short flags like -m
    if
      flag_pattern:match("^%-[^%-]")
      and part:match("^%-[^%-]")
      and part:find(flag_pattern:sub(2, 2))
    then
      return true
    end
  end
  return false
end

-- Detect if a command will be interactive (open an editor)
local function is_interactive_command(cmd_parts)
  if #cmd_parts == 0 then
    return false
  end

  local command = cmd_parts[1]

  -- Always interactive commands (unless bypassed)
  if command == "describe" or command == "desc" then
    return not (
      has_flag(cmd_parts, "-m")
      or has_flag(cmd_parts, "--message")
      or has_flag(cmd_parts, "--stdin")
      or has_flag(cmd_parts, "--no-edit")
    )
  end

  if command == "commit" then
    return not (has_flag(cmd_parts, "-m") or has_flag(cmd_parts, "--message"))
  end

  -- Commands that are always interactive
  if command == "split" or command == "diffedit" then
    return true
  end

  if command == "resolve" then
    return not has_flag(cmd_parts, "--list")
  end

  -- Additional interactive commands
  if command == "new" then
    return not (has_flag(cmd_parts, "-m") or has_flag(cmd_parts, "--message"))
  end

  if command == "edit" then
    return #cmd_parts == 1 -- edit without arguments is interactive
  end

  if command == "rebase" then
    return true -- rebase is generally interactive
  end

  return false
end

function M.jj(args)
  if not args or args == "" then
    M.status()
    return
  end

  -- Parse the first word to see if it's a command we handle specially
  local parts = vim.split(args, "%s+", { trimempty = true })
  local command = parts[1]
  local rest_args = table.concat(parts, " ", 2)

  -- Check if this is an interactive command that needs editor interception
  if is_interactive_command(parts) then
    -- Handle interactive commands
    if command == "describe" or command == "desc" then
      M.describe_interactive(parts)
      return
    elseif command == "commit" then
      M.commit_interactive(parts)
      return
    elseif command == "split" then
      M.split_interactive(parts)
      return
    elseif command == "diffedit" then
      M.diffedit_interactive(parts)
      return
    elseif command == "resolve" then
      M.resolve_interactive(parts)
      return
    end
  end

  -- Handle special commands that have custom implementations
  if command == "status" then
    M.status()
  elseif command == "diff" then
    M.diff(rest_args)
  elseif command == "log" then
    M.log(rest_args)
  elseif command == "browse" then
    require("jj-fugitive.browse").browse()
  else
    -- For all other commands, pass through to jj directly
    local result = run_jj_command(args)
    if result then
      -- For some commands, we might want to reload the status buffer
      if command == "commit" or command == "new" or command == "edit" then
        print(result)
        -- If status buffer is open, refresh it
        local status_module = require("jj-fugitive.status")
        for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_valid(bufnr) then
            local name = vim.api.nvim_buf_get_name(bufnr)
            if name:match("jj%-status$") then
              -- Refresh status buffer if it exists
              vim.schedule(function()
                status_module.show_status()
              end)
              break
            end
          end
        end
      else
        print(result)
      end
    end
  end
end

function M.status()
  require("jj-fugitive.status").show_status()
end

function M.diff(args)
  if not args or args == "" then
    -- Get current buffer filename
    local current_file = vim.api.nvim_buf_get_name(0)
    if current_file ~= "" then
      -- Convert to relative path if it's in the current working directory
      local cwd = vim.fn.getcwd()
      if current_file:find(cwd, 1, true) == 1 then
        current_file = current_file:sub(#cwd + 2) -- +2 to skip the trailing slash
      end
      require("jj-fugitive.diff").show_file_diff(current_file)
    else
      require("jj-fugitive.diff").show_all_diff()
    end
  else
    -- Parse arguments to see if it's a filename
    local filename = args:match("^%s*(.-)%s*$")
    if filename and filename ~= "" then
      require("jj-fugitive.diff").show_file_diff(filename)
    else
      require("jj-fugitive.diff").show_all_diff()
    end
  end
end

function M.log(args)
  local options = {}

  if args and args ~= "" then
    -- Parse basic options
    if args:match("%-%-limit%s+(%d+)") then
      options.limit = tonumber(args:match("%-%-limit%s+(%d+)"))
    end

    -- Parse revisions
    local revisions = {}
    for rev in args:gmatch("%-r%s+([^%s]+)") do
      table.insert(revisions, rev)
    end
    if #revisions > 0 then
      options.revisions = revisions
    end
  end

  require("jj-fugitive.log").show_log(options)
end

function M.complete(arglead, cmdline, cursorpos)
  return require("jj-fugitive.completion").complete(arglead, cmdline, cursorpos)
end

-- Expose the repository-aware command runner for other modules
function M.run_jj_command_from_module(args, options)
  return run_jj_command(args, options)
end

-- Expose repository root detection for other modules
function M.get_repo_root()
  return get_repo_root()
end

-- Interactive command implementation
function M.describe_interactive(cmd_parts)
  -- Extract revisions from command parts (default to @)
  local revisions = {}
  local i = 2 -- Start after command name
  while i <= #cmd_parts do
    local part = cmd_parts[i]
    if not part:match("^%-") then -- Not a flag
      table.insert(revisions, part)
    end
    i = i + 1
  end

  -- Default to current revision if none specified
  if #revisions == 0 then
    table.insert(revisions, "@")
  end
  local revision = revisions[1] -- Take first revision for now

  -- Get current description for the revision
  local show_result = run_jj_command({ "show", "-s", revision })
  if not show_result then
    return
  end

  -- Extract description from show output
  local description = ""
  local in_description = false
  for line in show_result:gmatch("[^\n]*") do
    if line:match("^%s*$") and in_description then
      break -- End of description
    elseif in_description then
      if description ~= "" then
        description = description .. "\n"
      end
      description = description .. line:gsub("^    ", "") -- Remove indentation
    elseif line:match("^Committer:") then
      in_description = true -- Description starts after committer line
    end
  end

  -- Create buffer for editing
  local bufnr = vim.api.nvim_create_buf(false, true)
  local buffer_name = string.format("jj-describe-%s", revision)

  -- Set buffer options
  vim.api.nvim_buf_set_option(bufnr, "buftype", "acwrite")
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  vim.api.nvim_buf_set_name(bufnr, buffer_name)
  vim.api.nvim_buf_set_option(bufnr, "filetype", "gitcommit")

  -- Set buffer content to current description
  local description_lines = vim.split(description, "\n")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, description_lines)

  -- Set up autocmd to save changes
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = bufnr,
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

      -- Filter out comment lines and empty lines
      local filtered_lines = {}
      for _, line in ipairs(lines) do
        if not line:match("^%s*#") and not line:match("^%s*$") then
          table.insert(filtered_lines, line)
        end
      end

      local new_description = table.concat(filtered_lines, "\n"):gsub("%s+$", "") -- Trim trailing whitespace

      if new_description == "" then
        vim.api.nvim_err_writeln("Empty description - not saved")
        return
      end

      -- Build command with proper escaping
      local result = run_jj_command({ "describe", revision, "-m", new_description })
      if result then
        vim.api.nvim_buf_set_option(bufnr, "modified", false)
        print("Description updated for " .. revision)

        -- Refresh status buffer if open
        local status_module = require("jj-fugitive.status")
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_valid(buf) then
            local name = vim.api.nvim_buf_get_name(buf)
            if name:match("jj%-status$") then
              vim.schedule(function()
                status_module.show_status()
              end)
              break
            end
          end
        end
      end
    end,
  })

  -- Open buffer in a new window
  vim.cmd("split")
  vim.api.nvim_win_set_buf(0, bufnr)

  -- Add helpful message as comments at the top
  local help_lines = {
    "# Enter description for revision " .. revision,
    "# Lines starting with # are ignored",
    "# Save to apply changes (:w)",
    "",
  }

  vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, help_lines)
  -- Move cursor to after help text
  vim.api.nvim_win_set_cursor(0, { #help_lines + 1, 0 })
end

function M.commit_interactive(cmd_parts)
  -- Extract filesets from command parts
  local filesets = {}
  local i = 2 -- Start after command name
  while i <= #cmd_parts do
    local part = cmd_parts[i]
    if not part:match("^%-") then -- Not a flag
      table.insert(filesets, part)
    end
    i = i + 1
  end

  -- Get current description for the working copy revision (@)
  local show_result = run_jj_command({ "show", "-s", "@" })
  if not show_result then
    return
  end

  -- Extract description from show output
  local description = ""
  local in_description = false
  for line in show_result:gmatch("[^\n]*") do
    if line:match("^%s*$") and in_description then
      break -- End of description
    elseif in_description then
      if description ~= "" then
        description = description .. "\n"
      end
      description = description .. line:gsub("^    ", "") -- Remove indentation
    elseif line:match("^Committer:") then
      in_description = true -- Description starts after committer line
    end
  end

  -- Create buffer for editing
  local bufnr = vim.api.nvim_create_buf(false, true)
  local buffer_name = "jj-commit"

  -- Set buffer options
  vim.api.nvim_buf_set_option(bufnr, "buftype", "acwrite")
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  vim.api.nvim_buf_set_name(bufnr, buffer_name)
  vim.api.nvim_buf_set_option(bufnr, "filetype", "gitcommit")

  -- Set buffer content to current description
  local description_lines = vim.split(description, "\n")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, description_lines)

  -- Set up autocmd to save changes
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = bufnr,
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

      -- Filter out comment lines and empty lines
      local filtered_lines = {}
      for _, line in ipairs(lines) do
        if not line:match("^%s*#") and not line:match("^%s*$") then
          table.insert(filtered_lines, line)
        end
      end

      local new_description = table.concat(filtered_lines, "\n"):gsub("%s+$", "") -- Trim trailing whitespace

      if new_description == "" then
        vim.api.nvim_err_writeln("Empty description - not saved")
        return
      end

      -- Build commit command with filesets if provided
      local commit_args = { "commit", "-m", new_description }
      for _, fileset in ipairs(filesets) do
        table.insert(commit_args, fileset)
      end

      local result = run_jj_command(commit_args)
      if result then
        vim.api.nvim_buf_set_option(bufnr, "modified", false)
        print("Commit created: " .. new_description:gsub("\n.*", "") .. "...") -- Show first line

        -- Refresh status buffer if open
        local status_module = require("jj-fugitive.status")
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_valid(buf) then
            local name = vim.api.nvim_buf_get_name(buf)
            if name:match("jj%-status$") then
              vim.schedule(function()
                status_module.show_status()
              end)
              break
            end
          end
        end
      end
    end,
  })

  -- Open buffer in a new window
  vim.cmd("split")
  vim.api.nvim_win_set_buf(0, bufnr)

  -- Add helpful message as comments at the top
  local help_lines = {
    "# Enter commit message",
    "# Lines starting with # are ignored",
    "# Save to create commit (:w)",
    "",
  }

  if #filesets > 0 then
    table.insert(help_lines, 2, "# Committing filesets: " .. table.concat(filesets, ", "))
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, help_lines)
  -- Move cursor to after help text
  vim.api.nvim_win_set_cursor(0, { #help_lines + 1, 0 })
end

function M.split_interactive(cmd_parts) -- luacheck: ignore cmd_parts
  vim.api.nvim_err_writeln(
    "Interactive split requires diff editor integration (not yet implemented)"
  )
  vim.api.nvim_echo({
    { "Alternative: Use ", "Normal" },
    { "jj split -i ", "String" },
    { "in terminal for interactive split", "Normal" },
  }, false, {})
end

function M.diffedit_interactive(cmd_parts) -- luacheck: ignore cmd_parts
  vim.api.nvim_err_writeln(
    "Interactive diffedit requires diff editor integration (not yet implemented)"
  )
  vim.api.nvim_echo({
    { "Alternative: Use ", "Normal" },
    { "jj diffedit ", "String" },
    { "in terminal for interactive diff editing", "Normal" },
  }, false, {})
end

function M.resolve_interactive(cmd_parts) -- luacheck: ignore cmd_parts
  vim.api.nvim_err_writeln(
    "Interactive resolve requires merge tool integration (not yet implemented)"
  )
  vim.api.nvim_echo({
    { "Alternative: Use ", "Normal" },
    { "jj resolve ", "String" },
    { "in terminal for interactive conflict resolution", "Normal" },
  }, false, {})
end

-- Export is_interactive_command for testing
function M.is_interactive_command(cmd_parts)
  return is_interactive_command(cmd_parts)
end

-- Lightweight help entrypoint: opens plugin help or jj command help
function M.jhelp(args)
  -- No args: open vim help for this plugin
  if not args or args == "" then
    vim.cmd("help jj-fugitive")
    return
  end

  -- With args: show `jj <args> --help` output in a scratch buffer at repo root
  local parts = vim.split(args, "%s+", { trimempty = true })
  local cmd = {}
  for _, p in ipairs(parts) do
    table.insert(cmd, p)
  end
  table.insert(cmd, "--help")

  local out = run_jj_command(cmd)
  if not out then
    return
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
  vim.api.nvim_buf_set_name(bufnr, "jj-help")

  local lines = vim.split(out, "\n")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
  vim.api.nvim_buf_set_option(bufnr, "filetype", "help")

  vim.cmd("split")
  vim.api.nvim_set_current_buf(bufnr)
  require("jj-fugitive.ui").set_statusline(bufnr, "jj-help")
end

return M
