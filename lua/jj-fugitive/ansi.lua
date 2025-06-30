local M = {}

-- Parse ANSI escape sequences and convert to Neovim highlighting
function M.parse_ansi_colors(text)
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
function M.process_diff_content(diff_content, header_lines, _)
  -- options parameter not used but kept for API compatibility
  local lines = vim.split(diff_content, "\n")
  local processed_lines = {}
  local all_highlights = {}

  -- Add header if provided
  if header_lines then
    for _, line in ipairs(header_lines) do
      table.insert(processed_lines, line)
    end
  end

  -- Process each line to extract colors and clean text
  for i, line in ipairs(lines) do
    local clean_line, highlights = M.parse_ansi_colors(line)
    table.insert(processed_lines, clean_line)

    -- Adjust line numbers for highlights (account for header)
    local line_offset = header_lines and #header_lines or 0
    for _, hl in ipairs(highlights) do
      hl.line = i + line_offset - 1 -- Convert to 0-based indexing
      table.insert(all_highlights, hl)
    end
  end

  return processed_lines, all_highlights
end

-- Setup standard diff highlighting and apply parsed ANSI colors
function M.setup_diff_highlighting(bufnr, highlights, options)
  options = options or {}
  local prefix = options.prefix or "JjDiff"

  vim.api.nvim_buf_call(bufnr, function()
    -- Set the filetype to 'diff' for standard diff highlighting
    vim.cmd("setlocal filetype=diff")
    vim.cmd("setlocal conceallevel=0")

    -- Define highlight groups for diff colors
    vim.cmd(string.format("highlight %sAdd guifg=#00ff00 ctermfg=green", prefix))
    vim.cmd(string.format("highlight %sDelete guifg=#ff0000 ctermfg=red", prefix))
    vim.cmd(string.format("highlight %sChange guifg=#ffff00 ctermfg=yellow", prefix))
    vim.cmd(string.format("highlight %sBold gui=bold cterm=bold", prefix))

    -- Add custom highlighting based on options
    if options.custom_syntax then
      for pattern, group in pairs(options.custom_syntax) do
        vim.cmd(string.format("syntax match %s '%s'", group, pattern))
        if options.custom_highlights and options.custom_highlights[group] then
          vim.cmd(string.format("highlight default %s", options.custom_highlights[group]))
        else
          vim.cmd(string.format("highlight default link %s Comment", group))
        end
      end
    end
  end)

  -- Apply highlights from parsed ANSI codes
  if highlights then
    for _, hl in ipairs(highlights) do
      local group = hl.group
      -- Map generic colors to diff-specific ones for better appearance
      if group == "Green" or group == "LightGreen" then
        group = prefix .. "Add"
      elseif group == "Red" or group == "LightRed" then
        group = prefix .. "Delete"
      elseif group == "Yellow" or group == "LightYellow" then
        group = prefix .. "Change"
      elseif group == "Bold" then
        group = prefix .. "Bold"
      end

      -- Apply the highlight to the buffer
      local col_end = hl.col_end == -1 and -1 or hl.col_end
      pcall(vim.api.nvim_buf_add_highlight, bufnr, 0, group, hl.line, hl.col_start, col_end)
    end
  end
end

-- Create a colored diff/show buffer with consistent formatting
function M.create_colored_buffer(content, buffer_name, header_lines, options)
  options = options or {}

  -- Create unique buffer name with timestamp to avoid conflicts
  local timestamp = os.time()
  local unique_name = string.format("%s [%d]", buffer_name, timestamp)
  local bufnr = vim.api.nvim_create_buf(false, true)

  -- Set buffer options
  vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  vim.api.nvim_buf_set_name(bufnr, unique_name)

  -- Process content and extract ANSI colors
  local processed_lines, highlights = M.process_diff_content(content, header_lines, options)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, processed_lines)

  -- Setup highlighting with parsed ANSI colors
  M.setup_diff_highlighting(bufnr, highlights, options)

  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

  return bufnr
end

-- Update existing buffer with new colored content
function M.update_colored_buffer(bufnr, content, header_lines, options)
  options = options or {}

  -- Make buffer modifiable temporarily
  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)

  -- Clear existing content
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

  -- Clear existing highlights
  vim.api.nvim_buf_clear_namespace(bufnr, -1, 0, -1)

  -- Process content and extract ANSI colors
  local processed_lines, highlights = M.process_diff_content(content, header_lines, options)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, processed_lines)

  -- Setup highlighting with parsed ANSI colors
  M.setup_diff_highlighting(bufnr, highlights, options)

  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
end

return M
