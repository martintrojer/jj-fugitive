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

  local result = run_jj_command(args)
  if result then
    print(result)
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

function M.complete(arglead, cmdline, cursorpos) -- luacheck: ignore cmdline cursorpos
  local completions = {
    "status",
    "log",
    "diff",
    "commit",
    "new",
    "next",
    "prev",
    "edit",
    "bookmark",
  }

  local matches = {}
  for _, completion in ipairs(completions) do
    if completion:find("^" .. vim.pesc(arglead)) then
      table.insert(matches, completion)
    end
  end

  return matches
end

return M
