local M = {}

-- Find the jj repository root starting from a given directory
local function find_jj_root(start_path)
  local path = start_path or vim.fn.getcwd()

  -- Convert to absolute path and normalize (remove trailing slash)
  path = vim.fn.fnamemodify(path, ":p")
  if path:sub(-1) == "/" and path ~= "/" then
    path = path:sub(1, -2)
  end

  -- Walk up the directory tree looking for .jj directory
  while path ~= "/" and path ~= "" do
    local jj_dir = path .. "/.jj"
    if vim.fn.isdirectory(jj_dir) == 1 then
      return path
    end

    -- Go up one directory
    local parent = vim.fn.fnamemodify(path, ":h")
    if parent == path then
      break -- Reached root
    end
    path = parent
  end

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
  local old_cwd = vim.fn.getcwd()
  local success = pcall(vim.cmd, "cd " .. vim.fn.fnameescape(repo_root))
  if not success then
    vim.api.nvim_err_writeln("Failed to change to repository root: " .. repo_root)
    return nil
  end

  local result = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error

  -- Restore original working directory
  pcall(vim.cmd, "cd " .. vim.fn.fnameescape(old_cwd))

  if exit_code ~= 0 then
    vim.api.nvim_err_writeln("jj command failed: " .. result)
    return nil
  end
  return result, repo_root
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

  -- Handle special commands that have custom implementations
  if command == "status" then
    M.status()
  elseif command == "diff" then
    M.diff(rest_args)
  elseif command == "log" then
    M.log(rest_args)
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

return M
