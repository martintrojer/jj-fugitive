local M = {}

-- Regex pattern constants for common patterns used across the plugin
M.PATTERNS = {
  -- Status view patterns
  STATUS_LINE = "^[A-Z] ", -- Matches status lines like "M file.txt"
  STATUS_FILENAME = "^[A-Z] (.+)", -- Extracts filename from status line
  WORKING_COPY_HEADER = "^Working copy",
  WORKING_COPY_CHANGES = "^Working copy changes:",
  PARENT_COMMIT = "^Parent commit",

  -- Commit ID patterns
  COMMIT_ID_8_HEX = "([a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9])$",
  COMMIT_ID_WORKING_COPY = "^Working copy%s+%(@%)%s*:%s*%w+%s+([a-f0-9]+)",
  COMMIT_ID_PARENT = "^Parent commit%s+%(@%-%):%s*%w+%s+([a-f0-9]+)",

  -- Common line patterns
  EMPTY_LINE = "^%s*$",
  COMMENT_LINE = "^%s*#",
  COMMITTER_LINE = "^Committer:",

  -- Flag/option patterns
  FLAG_START = "^%-", -- Starts with dash (short or long flag)
  LONG_FLAG_START = "^%-%-", -- Starts with double dash (long flag)
}

-- Create a standard scratch buffer with common options
-- opts = {
--   name=string, unique=true|false, filetype=string, modifiable=false,
--   buftype="nofile"|"acwrite", mark_plugin=true|false
-- }
function M.create_scratch_buffer(opts)
  opts = opts or {}

  local bufnr = vim.api.nvim_create_buf(false, true)

  -- Set buffer options with defaults
  vim.api.nvim_buf_set_option(bufnr, "buftype", opts.buftype or "nofile")
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", opts.bufhidden or "wipe")
  vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", opts.modifiable == true)

  if opts.filetype then
    vim.api.nvim_buf_set_option(bufnr, "filetype", opts.filetype)
  end

  if opts.name and opts.name ~= "" then
    local name = opts.name
    if opts.unique then
      local ts = os.time()
      name = string.format("%s [%d]", name, ts)
    end
    vim.api.nvim_buf_set_name(bufnr, name)
  end

  -- Mark as plugin buffer if requested
  if opts.mark_plugin then
    pcall(vim.api.nvim_buf_set_var, bufnr, "jj_plugin_buffer", true)
  end

  return bufnr
end

-- Ensure a buffer is visible: if already displayed, jump to that window,
-- otherwise open a horizontal split and show it
function M.ensure_buffer_visible(bufnr)
  local existing_win = nil
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
      existing_win = win
      break
    end
  end

  if existing_win then
    vim.api.nvim_set_current_win(existing_win)
  else
    vim.cmd("split")
    vim.api.nvim_set_current_buf(bufnr)
  end
end

-- Open a floating help window with provided lines
-- opts = { title=string, width=number, height=number, close_keys={...} }
function M.show_help_popup(title, lines, opts)
  opts = opts or {}

  -- Create as modifiable to insert content, then lock it down
  local help_buf = M.create_scratch_buffer({ filetype = "markdown", modifiable = true })
  vim.api.nvim_buf_set_lines(help_buf, 0, -1, false, lines or {})
  vim.api.nvim_buf_set_option(help_buf, "modifiable", false)

  -- Optionally mark this as a plugin buffer
  if opts.mark_plugin then
    pcall(vim.api.nvim_buf_set_var, help_buf, "jj_plugin_buffer", true)
  end

  local win_width = vim.api.nvim_get_option("columns")
  local win_height = vim.api.nvim_get_option("lines")
  local width = math.min(opts.width or 60, win_width - 4)
  local height = math.min(opts.height or (#(lines or {}) + 2), win_height - 4)

  local win_opts = {
    relative = "editor",
    width = width,
    height = height,
    row = (win_height - height) / 2,
    col = (win_width - width) / 2,
    style = "minimal",
    border = "rounded",
  }

  if title and title ~= "" then
    win_opts.title = " " .. title .. " "
    win_opts.title_pos = "center"
  end

  local help_win = vim.api.nvim_open_win(help_buf, true, win_opts)

  local function close()
    if vim.api.nvim_win_is_valid(help_win) then
      vim.api.nvim_win_close(help_win, true)
    end
  end

  -- Default close keys
  vim.keymap.set("n", "<CR>", close, { buffer = help_buf, noremap = true, silent = true })
  vim.keymap.set("n", "<Esc>", close, { buffer = help_buf, noremap = true, silent = true })

  for _, key in ipairs(opts.close_keys or {}) do
    vim.keymap.set("n", key, close, { buffer = help_buf, noremap = true, silent = true })
  end

  return help_buf, help_win
end

-- Simple buffer name predicate for jj buffers used by the plugin
function M.is_jj_buffer(bufnr)
  local ok, val = pcall(vim.api.nvim_buf_get_var, bufnr, "jj_plugin_buffer")
  return ok and val == true
end

-- Set a custom statusline for a buffer
function M.set_statusline(bufnr, text)
  vim.api.nvim_buf_call(bufnr, function()
    vim.cmd("setlocal statusline=" .. vim.fn.escape(text or "", " \\ "))
  end)
end

-- Standardized error message writing
-- Provides consistent error formatting across the plugin
function M.err_write(msg)
  vim.api.nvim_err_writeln(msg)
end

-- Buffer-local keymap helper with sane defaults
-- mode: string or table, lhs: string, rhs: fn|string, opts: table
function M.map(bufnr, mode, lhs, rhs, opts)
  local base = { buffer = bufnr, noremap = true, silent = true }
  if opts then
    base = vim.tbl_extend("force", base, opts)
  end
  vim.keymap.set(mode, lhs, rhs, base)
end

-- Mark a per-buffer flag once and return true if this is the first time
-- Usage: if ui.set_once(bufnr, "status_keymaps") then ... end
function M.set_once(bufnr, key)
  local var = "jj_once_" .. tostring(key)
  local already = false
  pcall(function()
    already = vim.api.nvim_buf_get_var(bufnr, var) == true
  end)
  if already then
    return false
  end
  pcall(vim.api.nvim_buf_set_var, bufnr, var, true)
  return true
end

-- Back/quit helpers (added for consistent 'b' and 'q' behavior)
-- Resolve previous view and navigate or run a fallback action
function M.go_back_or_close(bufnr, fallback)
  local ok, prev = pcall(vim.api.nvim_buf_get_var, bufnr, "jj_previous_view")
  if ok and type(prev) == "string" then
    if prev == "status" then
      pcall(function()
        require("jj-fugitive.status").show_status()
      end)
      return
    elseif prev == "log" then
      pcall(function()
        require("jj-fugitive.log").show_log({ update_current = true })
      end)
      return
    end
  end

  if type(fallback) == "function" then
    fallback()
  else
    vim.cmd(tostring(fallback or "close"))
  end
end

-- Setup common 'q' (close) and 'b' (back) keymaps
-- opts = { close_cmd = 'close'|'bdelete!'|..., include_gq = boolean }
function M.setup_exit_keymaps(bufnr, opts)
  opts = opts or {}
  local close_cmd = opts.close_cmd or "close"
  local include_gq = opts.include_gq

  -- q to close
  M.map(bufnr, "n", "q", function()
    vim.cmd(close_cmd)
  end)

  -- optional gq to close (some views support this)
  if include_gq then
    M.map(bufnr, "n", "gq", function()
      vim.cmd(close_cmd)
    end)
  end

  -- b to go back or close
  M.map(bufnr, "n", "b", function()
    M.go_back_or_close(bufnr, function()
      vim.cmd(close_cmd)
    end)
  end)
end

-- Show a confirmation dialog and return true if user confirms
-- message: string - The confirmation message
-- default_no: boolean - If true, default to "No" (default: false)
function M.confirm_action(message, default_no)
  local default_choice = default_no and 2 or 1
  return vim.fn.confirm(message, "&Yes\n&No", default_choice) == 1
end

-- Get buffer variable safely with default value
-- Returns the variable value or default if not found/error
function M.get_buf_var_safe(bufnr, var_name, default)
  local ok, val = pcall(vim.api.nvim_buf_get_var, bufnr, var_name)
  return ok and val or default
end

-- Store view context (previous view and log limit) for navigation
-- This is used to enable 'b' key to navigate back to previous views
function M.store_view_context(bufnr, previous_view, log_limit)
  pcall(vim.api.nvim_buf_set_var, bufnr, "jj_previous_view", previous_view or "log")
  if log_limit then
    pcall(vim.api.nvim_buf_set_var, bufnr, "jj_log_limit", log_limit)
  end
end

-- Setup side-by-side diff buffer keymaps
-- Common keymaps for side-by-side diff views (used in diff.lua and log.lua)
function M.setup_sidebyside_keymaps(bufnr, filename)
  M.map(bufnr, "n", "q", function()
    vim.cmd("tabclose")
  end)
  M.map(bufnr, "n", "b", function()
    vim.cmd("tabclose")
  end)
  if filename then
    M.map(bufnr, "n", "u", function()
      require("jj-fugitive.diff").show_file_diff(filename)
    end)
    M.map(bufnr, "n", "o", function()
      vim.cmd("edit " .. vim.fn.fnameescape(filename))
    end)
  end
end

-- Find buffer by name pattern
-- Returns the first buffer that matches the pattern, or nil if not found
function M.find_buffer_by_pattern(pattern)
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name:match(pattern) then
        return bufnr
      end
    end
  end
  return nil
end

return M
