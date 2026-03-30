local M = {}

-- Configuration with defaults
M.config = {
  default_command = "log", -- "log" or "status"
  open_mode = "split", -- "split" or "tab"
  ignore_immutable = false, -- add --ignore-immutable to jj commands
}

--- Setup function for user configuration.
function M.setup(opts)
  M.config = vim.tbl_extend("force", M.config, opts or {})
end

-- Cache the last known repo root so plugin buffers (jj-log, jj-diff, etc.)
-- can still find the repo even though they have no real file path.
local last_repo_root = nil

--- Find the jj repository root from the current buffer or cwd.
--- Uses vim.fs.find (Neovim 0.8+) to walk upward.
local function find_jj_root()
  -- Try from current buffer's directory first
  local buf_name = vim.api.nvim_buf_get_name(0)
  if buf_name ~= "" then
    local buf_dir = vim.fn.fnamemodify(buf_name, ":p:h")
    -- Only search if it looks like a real filesystem path
    if vim.fn.isdirectory(buf_dir) == 1 then
      local found = vim.fs.find(".jj", { path = buf_dir, upward = true, type = "directory" })
      if #found > 0 then
        last_repo_root = vim.fn.fnamemodify(found[1], ":h")
        return last_repo_root
      end
    end
  end

  -- Try from cwd
  local found = vim.fs.find(".jj", { path = vim.fn.getcwd(), upward = true, type = "directory" })
  if #found > 0 then
    last_repo_root = vim.fn.fnamemodify(found[1], ":h")
    return last_repo_root
  end

  -- Fall back to cached root (for plugin buffers like jj-log)
  if last_repo_root and vim.fn.isdirectory(last_repo_root .. "/.jj") == 1 then
    return last_repo_root
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

  local cmd_args = { "jj", "-R", repo_root }
  if M.config.ignore_immutable then
    table.insert(cmd_args, "--ignore-immutable")
  end

  if type(args) == "string" then
    for arg in args:gmatch("%S+") do
      table.insert(cmd_args, arg)
    end
  elseif type(args) == "table" then
    vim.list_extend(cmd_args, args)
  else
    ui.err("Invalid arguments to run_jj")
    return nil
  end

  local result = vim
    .system(cmd_args, {
      cwd = repo_root,
      env = { JJ_EDITOR = "true" },
    })
    :wait()

  if result.code ~= 0 then
    ui.err("jj: " .. (result.stderr or result.stdout or "unknown error"))
    return nil
  end

  return result.stdout, repo_root
end

--- Get the repository root path (or nil).
function M.repo_root()
  return find_jj_root()
end

-- Commands that open a TUI and need :terminal instead of vim.fn.system
local TUI_COMMANDS = { "arrange", "split", "diffedit", "resolve" }

--- Run a jj command in a terminal buffer (for TUI commands).
--- Opens a split with the terminal, refreshes log on exit.
function M.run_jj_terminal(args)
  local ui = require("jj-fugitive.ui")
  local repo_root = find_jj_root()
  if not repo_root then
    ui.err("Not in a jj repository")
    return
  end

  local immutable_flag = M.config.ignore_immutable and " --ignore-immutable" or ""
  local args_str = type(args) == "table" and table.concat(args, " ") or args
  if not args_str then
    return
  end
  local cmd_str = "jj -R " .. vim.fn.shellescape(repo_root) .. immutable_flag .. " " .. args_str

  -- Show hint for builtin TUI keybindings
  vim.api.nvim_echo({
    { "jj builtin TUI keybindings:\n", "MoreMsg" },
    { "  Space/Enter  toggle selection\n", "Comment" },
    { "  c            confirm\n", "Comment" },
    { "  q            cancel\n", "Comment" },
    { "  ?            help", "Comment" },
  }, true, {})

  -- Open terminal in a new tab so it gets full screen
  -- Use jj's builtin TUI editors to avoid nested $EDITOR
  vim.cmd("tabnew")
  local term_buf = vim.api.nvim_get_current_buf()
  vim.fn.termopen("JJ_EDITOR=:builtin JJ_DIFF_EDITOR=:builtin " .. cmd_str, {
    on_exit = function(_, exit_code)
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(term_buf) then
          vim.api.nvim_buf_delete(term_buf, { force = true })
        end
        if exit_code == 0 then
          M.refresh_log()
        end
      end)
    end,
  })
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
  elseif command == "annotate" or command == "blame" then
    require("jj-fugitive.annotate").show(rest ~= "" and rest or nil)
  elseif command == "browse" then
    require("jj-fugitive.browse").browse()
  elseif command == "push" then
    local result = M.run_jj({ "git", "push", unpack(parts, 2) })
    if result then
      print(result)
      M.refresh_views()
    end
  elseif command == "fetch" then
    local result = M.run_jj({ "git", "fetch", unpack(parts, 2) })
    if result then
      print(result)
      M.refresh_views()
    end
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
    end
    -- Always refresh — can't know which commands mutate (custom aliases)
    M.refresh_log()
  end
end

--- Refresh open plugin views after state changes.
function M.refresh_views()
  vim.schedule(function()
    local log = require("jj-fugitive.log")
    if log.is_open() then
      log.refresh()
    end
    require("jj-fugitive.status").refresh()
    require("jj-fugitive.bookmark").refresh()
  end)
end

--- Backwards-compatible alias.
function M.refresh_log()
  M.refresh_views()
end

--- Undo the last jj operation and refresh plugin views.
function M.undo()
  local result = M.run_jj({ "undo" })
  if result then
    vim.api.nvim_echo({ { "Undid last jj operation", "MoreMsg" } }, false, {})
    M.refresh_views()
    return true
  end
  return false
end

--- Command completion.
function M.complete(arglead, cmdline, cursorpos)
  return require("jj-fugitive.completion").complete(arglead, cmdline, cursorpos)
end

return M
