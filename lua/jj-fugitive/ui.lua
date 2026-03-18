local M = {}

--- Create a scratch buffer with standard options.
--- opts: { name, filetype, modifiable, buftype, bufhidden }
function M.create_scratch_buffer(opts)
  opts = opts or {}
  local bufnr = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_set_option(bufnr, "buftype", opts.buftype or "nofile")
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", opts.bufhidden or "wipe")
  vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", opts.modifiable == true)

  if opts.filetype then
    vim.api.nvim_buf_set_option(bufnr, "filetype", opts.filetype)
  end

  if opts.name then
    pcall(vim.api.nvim_buf_set_name, bufnr, opts.name)
  end

  return bufnr
end

--- Set buffer lines and lock it (modifiable=false, modified=false).
function M.set_buf_lines(bufnr, lines)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
  vim.api.nvim_buf_set_option(bufnr, "modified", false)
end

--- Buffer-local keymap helper.
function M.map(bufnr, mode, lhs, rhs, opts)
  local base = { buffer = bufnr, noremap = true, silent = true }
  if opts then
    base = vim.tbl_extend("force", base, opts)
  end
  vim.keymap.set(mode, lhs, rhs, base)
end

--- Show an error message.
function M.err(msg)
  vim.api.nvim_err_writeln(msg)
end

--- Show a confirmation dialog. Returns true if user confirms.
function M.confirm(message)
  return vim.fn.confirm(message, "&Yes\n&No", 2) == 1
end

--- Set a custom statusline for a buffer.
function M.set_statusline(bufnr, text)
  vim.api.nvim_buf_call(bufnr, function()
    vim.cmd("setlocal statusline=" .. vim.fn.escape(text or "", " \\ "))
  end)
end

--- Get the plugin config table.
function M.get_config()
  return require("jj-fugitive").config
end

--- Open a new pane (split or tab) based on user config.
function M.open_pane()
  if M.get_config().open_mode == "tab" then
    vim.cmd("tabnew")
    -- Delete the [No Name] buffer that tabnew creates — we'll set our own
    local stray = vim.api.nvim_get_current_buf()
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(stray) and vim.api.nvim_buf_get_name(stray) == "" then
        pcall(vim.api.nvim_buf_delete, stray, { force = true })
      end
    end)
  else
    vim.cmd("split")
  end
end

--- Close command appropriate for open_mode (close split or tab).
function M.close_cmd()
  return M.get_config().open_mode == "tab" and "tabclose" or "close"
end

--- Ensure a buffer is visible. Jump to its window if already displayed,
--- otherwise open in a new pane.
function M.ensure_visible(bufnr)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
      vim.api.nvim_set_current_win(win)
      return
    end
  end
  M.open_pane()
  vim.api.nvim_set_current_buf(bufnr)
end

--- Find an existing buffer by name pattern. Returns bufnr or nil.
function M.find_buf(pattern)
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

--- Show a floating help popup.
--- lines: table of strings to display
--- opts: { title, width, close_keys }
function M.help_popup(title, lines, opts)
  opts = opts or {}
  local help_buf = M.create_scratch_buffer({ filetype = "markdown", modifiable = true })
  vim.api.nvim_buf_set_lines(help_buf, 0, -1, false, lines or {})
  vim.api.nvim_buf_set_option(help_buf, "modifiable", false)
  vim.api.nvim_buf_set_option(help_buf, "modified", false)

  local win_width = vim.api.nvim_get_option("columns")
  local win_height = vim.api.nvim_get_option("lines")
  local width = math.min(opts.width or 60, win_width - 4)
  local height = math.min(#(lines or {}) + 2, win_height - 4)

  local win_opts = {
    relative = "editor",
    width = width,
    height = height,
    row = (win_height - height) / 2,
    col = (win_width - width) / 2,
    style = "minimal",
    border = "rounded",
  }

  if title then
    win_opts.title = " " .. title .. " "
    win_opts.title_pos = "center"
  end

  local help_win = vim.api.nvim_open_win(help_buf, true, win_opts)

  local function close()
    if vim.api.nvim_win_is_valid(help_win) then
      vim.api.nvim_win_close(help_win, true)
    end
  end

  vim.keymap.set("n", "<CR>", close, { buffer = help_buf, noremap = true, silent = true })
  vim.keymap.set("n", "<Esc>", close, { buffer = help_buf, noremap = true, silent = true })
  vim.keymap.set("n", "q", close, { buffer = help_buf, noremap = true, silent = true })

  for _, key in ipairs(opts.close_keys or {}) do
    vim.keymap.set("n", key, close, { buffer = help_buf, noremap = true, silent = true })
  end

  -- Close popup when it loses focus
  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = help_buf,
    once = true,
    callback = close,
  })

  return help_buf, help_win
end

--- Open a side-by-side diff in a new tab using Neovim's diffthis.
--- left_content, right_content: strings
--- left_name, right_name: buffer names
--- filename: used for filetype detection (optional)
function M.open_sidebyside(left_content, left_name, right_content, right_name, filename)
  vim.cmd("tabnew")

  local left = M.create_scratch_buffer({ name = left_name, modifiable = true })
  vim.api.nvim_buf_set_lines(left, 0, -1, false, vim.split(left_content, "\n"))
  vim.api.nvim_buf_set_option(left, "modifiable", false)
  vim.api.nvim_buf_set_option(left, "modified", false)

  local right = M.create_scratch_buffer({ name = right_name, modifiable = true })
  vim.api.nvim_buf_set_lines(right, 0, -1, false, vim.split(right_content, "\n"))
  vim.api.nvim_buf_set_option(right, "modifiable", false)
  vim.api.nvim_buf_set_option(right, "modified", false)

  if filename then
    local ft = vim.filetype.match({ filename = filename })
    if ft then
      vim.api.nvim_buf_set_option(left, "filetype", ft)
      vim.api.nvim_buf_set_option(right, "filetype", ft)
    end
  end

  vim.api.nvim_set_current_buf(left)
  vim.cmd("vsplit")
  vim.cmd("wincmd l")
  vim.api.nvim_set_current_buf(right)
  vim.cmd("windo diffthis")

  for _, buf in ipairs({ left, right }) do
    M.map(buf, "n", "q", "<cmd>tabclose<CR>")
  end

  return left, right
end

return M
