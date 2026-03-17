local M = {}

-- Configuration with defaults
M.config = {
  default_command = "log", -- "log" or "status"
}

--- Setup function for user configuration.
function M.setup(opts)
  M.config = vim.tbl_extend("force", M.config, opts or {})
end

--- Find the jj repository root from the current buffer or cwd.
--- Uses vim.fs.find (Neovim 0.8+) to walk upward.
local function find_jj_root()
  -- Try from current buffer's directory first, then cwd
  local start_path
  local buf_name = vim.api.nvim_buf_get_name(0)
  if buf_name ~= "" then
    start_path = vim.fn.fnamemodify(buf_name, ":p:h")
  else
    start_path = vim.fn.getcwd()
  end

  local found = vim.fs.find(".jj", { path = start_path, upward = true, type = "directory" })
  if #found > 0 then
    return vim.fn.fnamemodify(found[1], ":h")
  end
  return nil
end

--- Run a jj command from the repository root.
--- args: string or table of arguments
--- Returns: output string, repo_root string (or nil on error)
function M.run_jj(args)
  local ui = require("jj-fugitive.ui")

  local repo_root = find_jj_root()
  if not repo_root then
    ui.err("Not in a jj repository")
    return nil
  end

  local cmd
  if type(args) == "string" then
    cmd = "jj " .. args
  elseif type(args) == "table" then
    cmd = vim.list_extend({ "jj" }, args)
  else
    ui.err("Invalid arguments to run_jj")
    return nil
  end

  local old_cwd = vim.fn.getcwd()
  local ok = pcall(vim.cmd, "lcd " .. vim.fn.fnameescape(repo_root))
  if not ok then
    ui.err("Failed to change to repository root: " .. repo_root)
    return nil
  end

  -- Suppress jj's editor to prevent hangs when running via vim.fn.system.
  -- Commands like squash, split, etc. would otherwise try to open $EDITOR.
  local saved_editor = vim.env.JJ_EDITOR
  vim.env.JJ_EDITOR = "true"
  local result = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error
  vim.env.JJ_EDITOR = saved_editor

  pcall(vim.cmd, "lcd " .. vim.fn.fnameescape(old_cwd))

  if exit_code ~= 0 then
    ui.err("jj: " .. result)
    return nil
  end

  return result, repo_root
end

--- Get the repository root path (or nil).
function M.repo_root()
  return find_jj_root()
end

-- Commands that open a TUI and need :terminal instead of vim.fn.system
local TUI_COMMANDS = { "arrange", "split" }

--- Run a jj command in a terminal buffer (for TUI commands).
--- Opens a split with the terminal, refreshes log on exit.
function M.run_jj_terminal(args)
  local ui = require("jj-fugitive.ui")
  local repo_root = find_jj_root()
  if not repo_root then
    ui.err("Not in a jj repository")
    return
  end

  local cmd_str
  if type(args) == "string" then
    cmd_str = "jj " .. args
  elseif type(args) == "table" then
    cmd_str = "jj " .. table.concat(args, " ")
  else
    return
  end

  -- Show hint for builtin TUI keybindings
  vim.api.nvim_echo({
    { "jj builtin TUI: ", "MoreMsg" },
    { "Space/Enter=toggle, c=confirm, q=cancel, ?=help", "Comment" },
  }, false, {})

  -- Open terminal in a new tab so it gets full screen
  -- Use jj's builtin TUI editors to avoid nested $EDITOR
  vim.cmd("tabnew")
  local term_buf = vim.api.nvim_get_current_buf()
  local env_prefix = "JJ_EDITOR=:builtin JJ_DIFF_EDITOR=:builtin"
  vim.fn.termopen(
    "cd " .. vim.fn.shellescape(repo_root) .. " && " .. env_prefix .. " " .. cmd_str,
    {
      on_exit = function(_, exit_code)
        -- Close the terminal tab
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(term_buf) then
            vim.api.nvim_buf_delete(term_buf, { force = true })
          end
          if exit_code == 0 then
            M.refresh_log()
          end
        end)
      end,
    }
  )
  vim.cmd("startinsert")
end

--- Main :J command dispatcher.
function M.jj(args)
  if not args or args == "" then
    if M.config.default_command == "status" then
      require("jj-fugitive.status").show()
    else
      require("jj-fugitive.log").show()
    end
    return
  end

  local parts = vim.split(args, "%s+", { trimempty = true })
  local command = parts[1]
  local rest = table.concat(parts, " ", 2)

  if command == "log" then
    local opts = {}
    if rest ~= "" then
      local limit = rest:match("%-%-limit%s+(%d+)")
      if limit then
        opts.limit = tonumber(limit)
      end
      local revisions = {}
      for rev in rest:gmatch("%-r%s+([^%s]+)") do
        table.insert(revisions, rev)
      end
      if #revisions > 0 then
        opts.revisions = revisions
      end
    end
    require("jj-fugitive.log").show(opts)
  elseif command == "status" or command == "st" then
    require("jj-fugitive.status").show()
  elseif command == "diff" then
    require("jj-fugitive.diff").show(rest ~= "" and rest or nil)
  elseif command == "bookmark" then
    require("jj-fugitive.bookmark").show()
  elseif command == "describe" or command == "desc" then
    local rev = rest ~= "" and rest or "@"
    require("jj-fugitive.describe").describe(rev)
  elseif command == "commit" then
    require("jj-fugitive.describe").commit()
  elseif command == "browse" then
    require("jj-fugitive.browse").browse()
  else
    -- TUI commands need a terminal, not vim.fn.system
    if vim.tbl_contains(TUI_COMMANDS, command) then
      M.run_jj_terminal(args)
      return
    end

    -- Pass through to jj
    local result = M.run_jj(args)
    if result then
      print(result)
      -- Refresh log if open after mutating commands
      local mutating = { "new", "edit", "squash", "abandon", "rebase", "parallelize" }
      if vim.tbl_contains(mutating, command) then
        M.refresh_log()
      end
    end
  end
end

--- Refresh the log buffer if one is currently open.
function M.refresh_log()
  vim.schedule(function()
    local log = require("jj-fugitive.log")
    if log.is_open() then
      log.refresh()
    end
  end)
end

--- Command completion.
function M.complete(arglead, cmdline, cursorpos)
  return require("jj-fugitive.completion").complete(arglead, cmdline, cursorpos)
end

return M
