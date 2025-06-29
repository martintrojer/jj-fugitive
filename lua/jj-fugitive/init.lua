local M = {}

local function run_jj_command(args)
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

  local result = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_err_writeln("jj command failed: " .. result)
    return nil
  end
  return result
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

return M
