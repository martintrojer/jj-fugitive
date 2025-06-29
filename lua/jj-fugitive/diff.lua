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
    -- Use git format for better compatibility and familiar output
    if options.format == "git" or not options.format then
      table.insert(cmd_args, "--git")
    end
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

-- Parse ANSI escape sequences and convert to Neovim highlighting
local function parse_ansi_colors(text)
  local highlights = {}
  local clean_text = ""
  local pos = 1
  local current_style = {}

  -- ANSI color code mappings - basic 3/4 bit colors
  local ansi_colors = {
    ["30"] = "Black",
    ["31"] = "Red",
    ["32"] = "Green",
    ["33"] = "Yellow",
    ["34"] = "Blue",
    ["35"] = "Magenta",
    ["36"] = "Cyan",
    ["37"] = "White",
    ["90"] = "DarkGray",
    ["91"] = "LightRed",
    ["92"] = "LightGreen",
    ["93"] = "LightYellow",
    ["94"] = "LightBlue",
    ["95"] = "LightMagenta",
    ["96"] = "LightCyan",
    ["97"] = "White",
  }

  -- Map 256-color palette indices to reasonable colors for diff
  local ansi_256_colors = {
    ["1"] = "Red", -- red for deletions
    ["2"] = "Green", -- green for additions
    ["3"] = "Yellow", -- yellow for changes
    ["4"] = "Blue", -- blue
    ["5"] = "Magenta", -- magenta
    ["6"] = "Cyan", -- cyan
    ["9"] = "LightRed", -- bright red
    ["10"] = "LightGreen", -- bright green
    ["11"] = "LightYellow", -- bright yellow
  }

  while pos <= #text do
    local esc_start, esc_end = text:find("\27%[[0-9;]*m", pos)

    if esc_start then
      -- Add text before escape sequence with current styling
      if esc_start > pos then
        local segment = text:sub(pos, esc_start - 1)
        if next(current_style) then
          table.insert(highlights, {
            group = current_style.group or "Normal",
            line = 0,
            col_start = #clean_text,
            col_end = #clean_text + #segment,
          })
        end
        clean_text = clean_text .. segment
      end

      -- Parse the escape sequence
      local codes = text:sub(esc_start + 2, esc_end - 1) -- Remove \27[ and m

      -- Handle different codes
      if codes == "0" or codes == "" then
        -- Reset all styles
        current_style = {}
      elseif codes == "1" then
        -- Bold
        current_style.bold = true
        current_style.group = "Bold"
      elseif codes == "4" then
        -- Underline
        current_style.underline = true
        current_style.group = "Underlined"
      elseif codes == "24" then
        -- No underline
        current_style.underline = false
        if not current_style.bold and not (current_style.color or current_style.bg_color) then
          current_style = {}
        end
      elseif codes == "39" then
        -- Default foreground color (reset)
        current_style.color = nil
        if
          not current_style.bold
          and not current_style.underline
          and not current_style.bg_color
        then
          current_style = {}
        end
      else
        -- Handle complex color codes like 38;5;n (256-color foreground)
        local codes_list = {}
        for code in codes:gmatch("[^;]+") do
          table.insert(codes_list, code)
        end

        local i = 1
        while i <= #codes_list do
          local code = codes_list[i]

          if code == "38" and codes_list[i + 1] == "5" and codes_list[i + 2] then
            -- 256-color foreground: 38;5;n
            local color_index = codes_list[i + 2]
            local color = ansi_256_colors[color_index]
            if color then
              current_style.color = color
              current_style.group = color
            end
            i = i + 3
          elseif ansi_colors[code] then
            -- Basic color
            current_style.color = ansi_colors[code]
            current_style.group = ansi_colors[code]
            i = i + 1
          else
            i = i + 1
          end
        end
      end

      pos = esc_end + 1
    else
      -- No more escape sequences, add rest of text with current styling
      local remaining = text:sub(pos)
      if #remaining > 0 then
        if next(current_style) then
          table.insert(highlights, {
            group = current_style.group or "Normal",
            line = 0,
            col_start = #clean_text,
            col_end = #clean_text + #remaining,
          })
        end
        clean_text = clean_text .. remaining
      end
      break
    end
  end

  return clean_text, highlights
end

-- Process diff content and parse ANSI colors
local function process_diff_content(diff_content, filename, options)
  options = options or {}
  local lines = vim.split(diff_content, "\n")
  local processed_lines = {}
  local all_highlights = {}

  -- Add minimal header with file info if requested
  if filename and not options.no_header then
    table.insert(processed_lines, "")
    table.insert(processed_lines, "# File: " .. filename)
    table.insert(processed_lines, "# Changes in working copy vs parent (@-)")
    table.insert(processed_lines, "")
  end

  -- Process each line to extract colors and clean text
  for i, line in ipairs(lines) do
    local clean_line, highlights = parse_ansi_colors(line)
    table.insert(processed_lines, clean_line)

    -- Adjust line numbers for highlights (account for header)
    local line_offset = filename and not options.no_header and 4 or 0
    for _, hl in ipairs(highlights) do
      hl.line = i + line_offset - 1 -- Convert to 0-based indexing
      table.insert(all_highlights, hl)
    end
  end

  return processed_lines, all_highlights
end

-- Setup diff highlighting and apply parsed ANSI colors
local function setup_diff_highlighting(bufnr, highlights)
  vim.api.nvim_buf_call(bufnr, function()
    -- Set the filetype to 'diff' for standard diff highlighting
    vim.cmd("setlocal filetype=diff")
    vim.cmd("setlocal conceallevel=0")

    -- Add some custom highlighting for our minimal headers
    vim.cmd("syntax match JjDiffFileHeader '^# File:.*$'")
    vim.cmd("syntax match JjDiffChangeHeader '^# Changes.*$'")
    vim.cmd("highlight default link JjDiffFileHeader Comment")
    vim.cmd("highlight default link JjDiffChangeHeader Comment")

    -- Define highlight groups for diff colors
    vim.cmd("highlight JjDiffAdd guifg=#00ff00 ctermfg=green")
    vim.cmd("highlight JjDiffDelete guifg=#ff0000 ctermfg=red")
    vim.cmd("highlight JjDiffChange guifg=#ffff00 ctermfg=yellow")
    vim.cmd("highlight JjDiffBold gui=bold cterm=bold")
  end)

  -- Apply highlights from parsed ANSI codes
  if highlights then
    for _, hl in ipairs(highlights) do
      local group = hl.group
      -- Map generic colors to diff-specific ones for better appearance
      if group == "Green" or group == "LightGreen" then
        group = "JjDiffAdd"
      elseif group == "Red" or group == "LightRed" then
        group = "JjDiffDelete"
      elseif group == "Yellow" or group == "LightYellow" then
        group = "JjDiffChange"
      elseif group == "Bold" then
        group = "JjDiffBold"
      end

      -- Apply the highlight to the buffer
      local col_end = hl.col_end == -1 and -1 or hl.col_end
      pcall(vim.api.nvim_buf_add_highlight, bufnr, 0, group, hl.line, hl.col_start, col_end)
    end
  end
end

-- Create a diff buffer with ANSI color parsing and highlighting
local function create_diff_buffer(filename, diff_content, options)
  options = options or {}

  -- Create unique buffer name with timestamp to avoid conflicts
  local timestamp = os.time()
  local format_desc = ""
  if options.color_words then
    format_desc = " (color-words)"
  elseif options.context then
    format_desc = " (context:" .. options.context .. ")"
  elseif options.ignore_whitespace then
    format_desc = " (no-ws)"
  end

  local bufname = string.format("jj-diff: %s%s [%d]", filename or "all", format_desc, timestamp)
  local bufnr = vim.api.nvim_create_buf(false, true)

  -- Set buffer options
  vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  vim.api.nvim_buf_set_name(bufnr, bufname)

  -- Process content and extract ANSI colors
  local processed_lines, highlights = process_diff_content(diff_content, filename, options)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, processed_lines)

  -- Setup highlighting with parsed ANSI colors
  setup_diff_highlighting(bufnr, highlights)

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
      "  s       - Switch to side-by-side view",
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
  local original_content =
    main_module.run_jj_command_from_module({ "file", "show", filename, "-r", "@-" })
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

return M
