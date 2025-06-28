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
  elseif command == "log" and rest_args == "" then
    -- Only use custom log for simple cases, fall back to jj for complex args
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

function M.log(args)
  local cmd_args = "log"
  if args and args ~= "" then
    cmd_args = cmd_args .. " " .. args
  end

  local result = run_jj_command(cmd_args)
  if result then
    print(result)
  end
end

function M.diff(args)
  if not args or args == "" then
    require("jj-fugitive.diff").show_all_diff()
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

function M.commit(args)
  local cmd_args = "commit"
  if args and args ~= "" then
    cmd_args = cmd_args .. " " .. args
  end

  local result = run_jj_command(cmd_args)
  if result then
    print(result)
  end
end

function M.new(args)
  local cmd_args = "new"
  if args and args ~= "" then
    cmd_args = cmd_args .. " " .. args
  end

  local result = run_jj_command(cmd_args)
  if result then
    print(result)
  end
end

function M.next()
  local result = run_jj_command("next")
  if result then
    print(result)
  end
end

function M.prev()
  local result = run_jj_command("prev")
  if result then
    print(result)
  end
end

function M.edit(args)
  local cmd_args = "edit"
  if args and args ~= "" then
    cmd_args = cmd_args .. " " .. args
  end

  local result = run_jj_command(cmd_args)
  if result then
    print(result)
  end
end

function M.bookmark(args)
  local cmd_args = "bookmark"
  if args and args ~= "" then
    cmd_args = cmd_args .. " " .. args
  else
    cmd_args = cmd_args .. " list"
  end

  local result = run_jj_command(cmd_args)
  if result then
    print(result)
  end
end

function M.complete(arglead, cmdline, cursorpos)
  return require("jj-fugitive.completion").complete(arglead, cmdline, cursorpos)
end

return M
