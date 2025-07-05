local M = {}

-- Get diff output from jj with native colorization
local function get_jj_diff(filename, options)
  options = options or {}

  -- Use the main module's repository-aware command runner
  local main_module = require("jj-fugitive.init")

  local cmd_args = { "diff" }

  -- Enable colors by default for better output
  if options.color ~= false then
    table.insert(cmd_args, "--color")
    table.insert(cmd_args, "always")
  else
    table.insert(cmd_args, "--color")
    table.insert(cmd_args, "never")
  end

  -- Handle mutually exclusive options properly
  if options.color_words then
    -- color-words cannot be used with --git
    table.insert(cmd_args, "--color-words")
  elseif options.tool then
    -- tool option overrides format
    table.insert(cmd_args, "--tool")
    table.insert(cmd_args, options.tool)
  else
    -- Use git format for better compatibility and familiar output (default)
    table.insert(cmd_args, "--git")
  end

  -- Add context lines if specified (works with git format)
  if options.context and not options.color_words then
    table.insert(cmd_args, "--context")
    table.insert(cmd_args, tostring(options.context))
  end

  -- Add whitespace options
  if options.ignore_whitespace then
    table.insert(cmd_args, "--ignore-all-space")
  end

  if filename then
    table.insert(cmd_args, filename)
  end

  local result = main_module.run_jj_command_from_module(cmd_args)
  if not result then
    return nil, "Failed to get diff"
  end
  return result, nil
end

-- Import shared ANSI parsing utilities
local ansi = require("jj-fugitive.ansi")

-- Create a diff buffer with ANSI color parsing and highlighting
local function create_diff_buffer(filename, diff_content, options)
  options = options or {}

  -- Create format description for buffer name
  local format_desc = ""
  if options.color_words then
    format_desc = " (color-words)"
  elseif options.context then
    format_desc = " (context:" .. options.context .. ")"
  elseif options.ignore_whitespace then
    format_desc = " (no-ws)"
  end

  local bufname = string.format("jj-diff: %s%s", filename or "all", format_desc)

  -- Create header lines for file diff
  local header_lines = nil
  if filename and not options.no_header then
    header_lines = {
      "",
      "# File: " .. filename,
      "# Changes in working copy vs parent (@-)",
      "",
    }
  end

  -- Use shared utility to create colored buffer
  local bufnr = ansi.create_colored_buffer(diff_content, bufname, header_lines, {
    prefix = "JjDiff",
    custom_syntax = {
      ["^# File:.*$"] = "JjDiffFileHeader",
      ["^# Changes.*$"] = "JjDiffChangeHeader",
    },
  })

  return bufnr
end

-- Setup diff buffer keymaps
local function setup_diff_keymaps(bufnr, filename)
  local opts = { noremap = true, silent = true, buffer = bufnr }

  -- Close diff buffer
  vim.keymap.set("n", "q", function()
    vim.cmd("close")
  end, opts)

  -- Toggle between unified and side-by-side view
  vim.keymap.set("n", "<Tab>", function()
    M.toggle_diff_view(filename)
  end, opts)

  -- Switch to side-by-side view
  vim.keymap.set("n", "s", function()
    M.show_file_diff_sidebyside(filename)
  end, opts)

  -- Switch to unified view
  vim.keymap.set("n", "u", function()
    M.show_file_diff(filename)
  end, opts)

  -- Toggle different diff formats
  vim.keymap.set("n", "f", function()
    M.show_file_diff_format_selector(filename)
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

  -- Add vim diff navigation (vim-fugitive standard)
  vim.keymap.set("n", "[c", function()
    vim.cmd("normal! [c")
  end, opts)

  vim.keymap.set("n", "]c", function()
    vim.cmd("normal! ]c")
  end, opts)

  -- Show help (vim-fugitive uses g?)
  vim.keymap.set("n", "g?", function()
    local help_lines = {
      "# jj-fugitive Diff View Help",
      "",
      "Navigation:",
      "  [c      - Previous change",
      "  ]c      - Next change",
      "",
      "Operations:",
      "  q       - Close diff view",
      "  Tab     - Toggle between unified/side-by-side view",
      "  s       - Switch to side-by-side view",
      "  u       - Switch to unified view",
      "  f       - Select diff format (git, color-words, etc.)",
      "  r       - Refresh diff",
      "  o       - Open file in editor",
      "  g?      - Show this help",
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

-- Show diff in unified format with native jj colorization
function M.show_file_diff(filename, options)
  options = options or { format = "git" } -- Default to git format

  local diff_output, err = get_jj_diff(filename, options)
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

  local bufnr = create_diff_buffer(filename, diff_output, options)
  setup_diff_keymaps(bufnr, filename)

  -- Open in new window (split or tab depending on environment)
  if vim.fn.has("gui_running") == 1 or vim.env.DISPLAY then
    vim.cmd("tabnew")
  else
    -- In headless mode, just switch to the buffer
    vim.cmd("new")
  end
  vim.api.nvim_set_current_buf(bufnr)

  -- Add status line info with current format
  vim.api.nvim_buf_call(bufnr, function()
    local file_desc = filename or "all changes"
    local format_desc = options.format or "default"
    if options.color_words then
      format_desc = "color-words"
    end
    vim.cmd(
      "setlocal statusline=jj-diff:\\ "
        .. vim.fn.escape(file_desc, " \\ ")
        .. "\\ ("
        .. format_desc
        .. ")"
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
  local main_module = require("jj-fugitive.init")
  -- Use modern jj file show command for getting file content at specific revision
  local original_content = main_module.run_jj_command_from_module({ "file", "show", filename, "-r", "@-" })
  if not original_content then
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

    vim.keymap.set("n", "g?", function()
      local help_lines = {
        "# jj-fugitive Side-by-Side Diff Help",
        "",
        "Left: Original file content",
        "Right: Current file content",
        "",
        "Keybindings:",
        "  q       - Close diff view",
        "  u       - Switch to unified diff view",
        "  o       - Open file in editor",
        "  [c / ]c - Navigate changes",
        "  g?      - Show this help",
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

-- Show diff format selector
function M.show_file_diff_format_selector(filename)
  local formats = {
    { name = "Git format (default)", options = { format = "git" } },
    { name = "Color words", options = { color_words = true } },
    { name = "Default jj format", options = {} },
    { name = "Git format + more context", options = { format = "git", context = 5 } },
    { name = "Ignore whitespace", options = { format = "git", ignore_whitespace = true } },
  }

  -- Create selection menu
  local choices = {}
  for i, format in ipairs(formats) do
    table.insert(choices, string.format("%d. %s", i, format.name))
  end

  vim.ui.select(choices, {
    prompt = "Select diff format:",
    format_item = function(item)
      return item
    end,
  }, function(choice)
    if choice then
      local index = tonumber(choice:match("^(%d+)%."))
      if index and formats[index] then
        M.show_file_diff(filename, formats[index].options)
      end
    end
  end)
end

-- Show diff for all changes
function M.show_all_diff()
  M.show_file_diff(nil)
end

-- Toggle between unified and side-by-side diff view
function M.toggle_diff_view(filename)
  if not filename then
    vim.api.nvim_echo({ { "Toggle diff requires a specific file", "WarningMsg" } }, false, {})
    return
  end

  -- Check current buffer to determine what view we're in
  local current_bufname = vim.api.nvim_buf_get_name(0)

  -- If we're in a side-by-side view (tab with multiple windows), switch to unified
  if vim.fn.tabpagenr("$") > 1 and current_bufname:match("jj%-diff.*%(") then
    -- Close current tab and show unified diff
    vim.cmd("tabclose")
    M.show_file_diff(filename)
  else
    -- We're in unified view or somewhere else, switch to side-by-side
    M.show_file_diff_sidebyside(filename)
  end
end

return M
