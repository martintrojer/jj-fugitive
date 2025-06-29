local M = {}

-- Get diff output from jj
local function get_jj_diff(filename, options)
  options = options or {}
  local cmd = { "jj", "diff" }

  if options.tool then
    table.insert(cmd, "--tool")
    table.insert(cmd, options.tool)
  end

  if options.color == false then
    table.insert(cmd, "--color")
    table.insert(cmd, "never")
  end

  if filename then
    table.insert(cmd, filename)
  end

  local result = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    return nil, "Failed to get diff: " .. result
  end
  return result, nil
end

-- Enhanced diff content processing and formatting
local function process_diff_content(diff_content, filename)
  local lines = vim.split(diff_content, "\n")
  local processed_lines = {}

  -- Add header with file info
  if filename then
    table.insert(processed_lines, "")
    table.insert(processed_lines, "📄 File: " .. filename)
    table.insert(processed_lines, "🔄 Changes in working copy vs parent (@-)")
    table.insert(processed_lines, string.rep("─", 60))
    table.insert(processed_lines, "")
  end

  -- Process each line for better readability
  for _, line in ipairs(lines) do
    if line:match("^diff %-%-git") then
      -- File header - make it more prominent
      table.insert(processed_lines, "")
      table.insert(processed_lines, "📁 " .. line)
    elseif line:match("^index") then
      -- Index line - less prominent
      table.insert(processed_lines, "🔗 " .. line)
    elseif line:match("^%-%-%- ") then
      -- Old file marker
      table.insert(processed_lines, "⬅️  " .. line)
    elseif line:match("^%+%+%+ ") then
      -- New file marker
      table.insert(processed_lines, "➡️  " .. line)
    elseif line:match("^@@") then
      -- Hunk header - make it stand out
      table.insert(processed_lines, "")
      table.insert(processed_lines, "📍 " .. line)
    elseif line:match("^%-") then
      -- Deleted line
      table.insert(processed_lines, "❌ " .. line:sub(2))
    elseif line:match("^%+") then
      -- Added line
      table.insert(processed_lines, "✅ " .. line:sub(2))
    else
      -- Context line or other
      if line:match("^%s") or line == "" then
        table.insert(processed_lines, "   " .. line)
      else
        table.insert(processed_lines, line)
      end
    end
  end

  return processed_lines
end

-- Setup enhanced diff highlighting
local function setup_diff_highlighting(bufnr)
  vim.api.nvim_buf_call(bufnr, function()
    -- Clear existing syntax
    vim.cmd("syntax clear")

    -- File and header highlighting
    vim.cmd("syntax match JjDiffHeader '^📄.*$'")
    vim.cmd("syntax match JjDiffSubHeader '^🔄.*$'")
    vim.cmd("syntax match JjDiffSeparator '^─\\+$'")
    vim.cmd("syntax match JjDiffFileHeader '^📁.*$'")
    vim.cmd("syntax match JjDiffIndex '^🔗.*$'")
    vim.cmd("syntax match JjDiffOldFile '^⬅️.*$'")
    vim.cmd("syntax match JjDiffNewFile '^➡️.*$'")
    vim.cmd("syntax match JjDiffHunk '^📍.*$'")

    -- Change highlighting with icons
    vim.cmd("syntax match JjDiffRemoved '^❌.*$'")
    vim.cmd("syntax match JjDiffAdded '^✅.*$'")
    vim.cmd("syntax match JjDiffContext '^   .*$'")

    -- Apply colors
    vim.cmd("highlight default JjDiffHeader ctermfg=14 guifg=Cyan cterm=bold gui=bold")
    vim.cmd("highlight default JjDiffSubHeader ctermfg=8 guifg=Gray cterm=italic gui=italic")
    vim.cmd("highlight default JjDiffSeparator ctermfg=8 guifg=Gray")
    vim.cmd("highlight default JjDiffFileHeader ctermfg=11 guifg=Yellow cterm=bold gui=bold")
    vim.cmd("highlight default JjDiffIndex ctermfg=8 guifg=Gray")
    vim.cmd("highlight default JjDiffOldFile ctermfg=12 guifg=LightBlue")
    vim.cmd("highlight default JjDiffNewFile ctermfg=12 guifg=LightBlue")
    vim.cmd("highlight default JjDiffHunk ctermfg=13 guifg=Magenta cterm=bold gui=bold")
    vim.cmd("highlight default JjDiffRemoved ctermfg=9 guifg=LightRed guibg=#2d1414")
    vim.cmd("highlight default JjDiffAdded ctermfg=10 guifg=LightGreen guibg=#142d14")
    vim.cmd("highlight default JjDiffContext ctermfg=7 guifg=LightGray")
  end)
end

-- Create a diff buffer with proper settings and enhanced formatting
local function create_diff_buffer(filename, diff_content)
  local bufname = string.format("jj-diff: %s", filename or "all")
  local bufnr = vim.api.nvim_create_buf(false, true)

  -- Set buffer options
  vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  vim.api.nvim_buf_set_name(bufnr, bufname)

  -- Process and set enhanced content
  local processed_lines = process_diff_content(diff_content, filename)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, processed_lines)

  -- Setup enhanced highlighting
  setup_diff_highlighting(bufnr)

  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

  return bufnr
end

-- Setup diff buffer keymaps
local function setup_diff_keymaps(bufnr, filename)
  local opts = { noremap = true, silent = true, buffer = bufnr }

  -- Close diff buffer
  vim.keymap.set("n", "q", function()
    vim.cmd("close")
  end, opts)

  -- Switch to side-by-side view
  vim.keymap.set("n", "s", function()
    M.show_file_diff_sidebyside(filename)
  end, opts)

  -- Refresh diff
  vim.keymap.set("n", "r", function()
    M.show_file_diff(filename)
  end, opts)

  -- Open the file being diffed
  vim.keymap.set("n", "o", function()
    if filename then
      vim.cmd("edit " .. vim.fn.fnameescape(filename))
    end
  end, opts)

  -- Show help
  vim.keymap.set("n", "?", function()
    local help_lines = {
      "# jj-fugitive Enhanced Diff View Help",
      "",
      "Visual indicators:",
      "  📄 File being diffed",
      "  📁 Git diff header",
      "  📍 Hunk locations (@@...@@)",
      "  ❌ Removed lines",
      "  ✅ Added lines",
      "",
      "Keybindings:",
      "  q     - Close diff view",
      "  s     - Switch to side-by-side view",
      "  r     - Refresh diff",
      "  o     - Open file in editor",
      "  ?     - Show this help",
      "",
      "Press any key to continue...",
    }

    local help_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(help_buf, 0, -1, false, help_lines)
    vim.api.nvim_buf_set_option(help_buf, "modifiable", false)
    vim.api.nvim_buf_set_option(help_buf, "filetype", "markdown")

    local win_width = vim.api.nvim_get_option("columns")
    local win_height = vim.api.nvim_get_option("lines")
    local width = math.min(60, win_width - 4)
    local height = math.min(#help_lines + 2, win_height - 4)

    local win_opts = {
      relative = "editor",
      width = width,
      height = height,
      row = (win_height - height) / 2,
      col = (win_width - width) / 2,
      style = "minimal",
      border = "rounded",
    }

    local help_win = vim.api.nvim_open_win(help_buf, true, win_opts)

    -- Close help on any key
    vim.keymap.set("n", "<CR>", function()
      vim.api.nvim_win_close(help_win, true)
    end, { buffer = help_buf, noremap = true, silent = true })

    vim.keymap.set("n", "<Esc>", function()
      vim.api.nvim_win_close(help_win, true)
    end, { buffer = help_buf, noremap = true, silent = true })
  end, opts)
end

-- Show diff in unified format (default)
function M.show_file_diff(filename)
  local diff_output, err = get_jj_diff(filename, { color = false })
  if not diff_output then
    vim.api.nvim_err_writeln(err)
    return
  end

  if diff_output:match("^%s*$") then
    vim.api.nvim_echo(
      { { "No changes in " .. (filename or "working copy"), "WarningMsg" } },
      false,
      {}
    )
    return
  end

  local bufnr = create_diff_buffer(filename, diff_output)
  setup_diff_keymaps(bufnr, filename)

  -- Open in new window (split or tab depending on environment)
  if vim.fn.has("gui_running") == 1 or vim.env.DISPLAY then
    vim.cmd("tabnew")
  else
    -- In headless mode, just switch to the buffer
    vim.cmd("new")
  end
  vim.api.nvim_set_current_buf(bufnr)

  -- Add enhanced status line info
  vim.api.nvim_buf_call(bufnr, function()
    local file_desc = filename or "all changes"
    -- Simple status line without problematic characters
    vim.cmd(
      "setlocal statusline=jj-diff:\\ " .. vim.fn.escape(file_desc, " \\ ") .. "\\ (enhanced)"
    )
  end)
end

local function get_or_create_sidebyside_buffer(name_pattern)
  -- Check if a buffer with this pattern already exists
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name:match(vim.pesc(name_pattern)) then
        return bufnr
      end
    end
  end

  -- Create new buffer if none exists
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)

  -- Add timestamp to make buffer name unique
  local timestamp = os.time()
  local unique_name = name_pattern .. " [" .. timestamp .. "]"
  vim.api.nvim_buf_set_name(bufnr, unique_name)

  return bufnr
end

-- Show diff in side-by-side format
function M.show_file_diff_sidebyside(filename)
  if not filename then
    vim.api.nvim_err_writeln("Side-by-side diff requires a specific file")
    return
  end

  -- Get the original file content (before changes)
  local original_content = vim.fn.system({ "jj", "file", "show", filename, "-r", "@-" })
  if vim.v.shell_error ~= 0 then
    -- File might be newly added, so original content is empty
    original_content = ""
  end

  -- Get current file content
  local current_content = ""
  if vim.fn.filereadable(filename) == 1 then
    local file = io.open(filename, "r")
    if file then
      current_content = file:read("*all")
      file:close()
    end
  end

  -- Create side-by-side layout
  vim.cmd("tabnew")

  -- Left side: original content
  local original_buf = get_or_create_sidebyside_buffer("jj-diff: " .. filename .. " (original)")
  vim.api.nvim_buf_set_option(original_buf, "modifiable", true)

  local original_lines = vim.split(original_content, "\n")
  vim.api.nvim_buf_set_lines(original_buf, 0, -1, false, original_lines)
  vim.api.nvim_buf_set_option(original_buf, "modifiable", false)

  -- Set filetype based on file extension
  local ft = vim.filetype.match({ filename = filename })
  if ft then
    vim.api.nvim_buf_set_option(original_buf, "filetype", ft)
  end

  vim.api.nvim_set_current_buf(original_buf)

  -- Split vertically for current content
  vim.cmd("vsplit")

  -- Right side: current content
  local current_buf = get_or_create_sidebyside_buffer("jj-diff: " .. filename .. " (current)")
  vim.api.nvim_buf_set_option(current_buf, "modifiable", true)

  local current_lines = vim.split(current_content, "\n")
  vim.api.nvim_buf_set_lines(current_buf, 0, -1, false, current_lines)
  vim.api.nvim_buf_set_option(current_buf, "modifiable", false)

  if ft then
    vim.api.nvim_buf_set_option(current_buf, "filetype", ft)
  end

  vim.api.nvim_set_current_buf(current_buf)

  -- Setup keymaps for both buffers
  local setup_sidebyside_keys = function(buf)
    local opts = { noremap = true, silent = true, buffer = buf }

    vim.keymap.set("n", "q", function()
      vim.cmd("tabclose")
    end, opts)

    vim.keymap.set("n", "u", function()
      M.show_file_diff(filename)
    end, opts)

    vim.keymap.set("n", "o", function()
      vim.cmd("edit " .. vim.fn.fnameescape(filename))
    end, opts)

    vim.keymap.set("n", "?", function()
      local help_lines = {
        "# jj-fugitive Side-by-Side Diff Help",
        "",
        "Left: Original file content",
        "Right: Current file content",
        "",
        "Keybindings:",
        "  q     - Close diff view",
        "  u     - Switch to unified diff view",
        "  o     - Open file in editor",
        "  ?     - Show this help",
        "",
        "Press any key to continue...",
      }

      local help_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(help_buf, 0, -1, false, help_lines)
      vim.api.nvim_buf_set_option(help_buf, "modifiable", false)
      vim.api.nvim_buf_set_option(help_buf, "filetype", "markdown")

      local win_width = vim.api.nvim_get_option("columns")
      local win_height = vim.api.nvim_get_option("lines")
      local width = math.min(60, win_width - 4)
      local height = math.min(#help_lines + 2, win_height - 4)

      local win_opts = {
        relative = "editor",
        width = width,
        height = height,
        row = (win_height - height) / 2,
        col = (win_width - width) / 2,
        style = "minimal",
        border = "rounded",
      }

      local help_win = vim.api.nvim_open_win(help_buf, true, win_opts)

      vim.keymap.set("n", "<CR>", function()
        vim.api.nvim_win_close(help_win, true)
      end, { buffer = help_buf, noremap = true, silent = true })

      vim.keymap.set("n", "<Esc>", function()
        vim.api.nvim_win_close(help_win, true)
      end, { buffer = help_buf, noremap = true, silent = true })
    end, opts)
  end

  setup_sidebyside_keys(original_buf)
  setup_sidebyside_keys(current_buf)

  -- Enable diff mode
  vim.cmd("windo diffthis")

  -- Set status line
  vim.api.nvim_buf_call(original_buf, function()
    vim.cmd(
      "setlocal statusline=jj-diff:\\ " .. filename .. "\\ (original)\\ \\ [Press\\ ?\\ for\\ help]"
    )
  end)

  vim.api.nvim_buf_call(current_buf, function()
    vim.cmd(
      "setlocal statusline=jj-diff:\\ " .. filename .. "\\ (current)\\ \\ [Press\\ ?\\ for\\ help]"
    )
  end)
end

-- Show diff for all changes
function M.show_all_diff()
  M.show_file_diff(nil)
end

return M
