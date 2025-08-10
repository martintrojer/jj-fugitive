local M = {}

-- Create a standard scratch buffer with common options
-- opts = { name=string, unique=true|false, filetype=string, modifiable=false }
function M.create_scratch_buffer(opts)
  opts = opts or {}

  local bufnr = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
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

  local help_buf = M.create_scratch_buffer({ filetype = "markdown", modifiable = false })
  vim.api.nvim_buf_set_lines(help_buf, 0, -1, false, lines or {})

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
  local name = vim.api.nvim_buf_get_name(bufnr)
  return name:match("jj%-") ~= nil
end

-- Set a custom statusline for a buffer
function M.set_statusline(bufnr, text)
  vim.api.nvim_buf_call(bufnr, function()
    vim.cmd("setlocal statusline=" .. vim.fn.escape(text or "", " \\ "))
  end)
end

-- Buffer-local keymap helper with sane defaults
-- mode: string or table, lhs: string, rhs: fn|string, opts: table
function M.map(bufnr, mode, lhs, rhs, opts)
  local base = { buffer = bufnr, noremap = true, silent = true }
  if opts then
    for k, v in pairs(opts) do
      base[k] = v
    end
  end
  vim.keymap.set(mode, lhs, rhs, base)
end

return M
