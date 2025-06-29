local M = {}

local function get_or_create_status_buffer()
  -- First, check if a jj-status buffer already exists
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name:match("jj%-status$") then
        return bufnr
      end
    end
  end

  -- Create new buffer if none exists
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
  vim.api.nvim_buf_set_name(bufnr, "jj-status")
  return bufnr
end

local function get_jj_status()
  local result = vim.fn.system({ "jj", "status" })
  if vim.v.shell_error ~= 0 then
    return nil, "Failed to get jj status: " .. result
  end
  return result, nil
end

local function parse_status_output(output)
  local lines = vim.split(output, "\n")
  local status_info = {
    working_copy = "",
    parent = "",
    changes = {},
  }

  local in_changes = false

  for _, line in ipairs(lines) do
    if line:match("^Working copy changes:") then
      in_changes = true
    elseif line:match("^Working copy") then
      status_info.working_copy = line
      in_changes = false
    elseif line:match("^Parent commit") then
      status_info.parent = line
      in_changes = false
    elseif in_changes and line:match("^[A-Z]") then
      local status_char = line:sub(1, 1)
      local filename = line:sub(3)
      table.insert(status_info.changes, {
        status = status_char,
        file = filename,
        line = line,
      })
    end
  end

  return status_info
end

local function format_status_buffer(status_info)
  local lines = {}

  -- Header
  table.insert(lines, "# jj-fugitive Status")
  table.insert(lines, "")

  -- Working copy info
  if status_info.working_copy ~= "" then
    table.insert(lines, status_info.working_copy)
  end
  if status_info.parent ~= "" then
    table.insert(lines, status_info.parent)
  end
  table.insert(lines, "")

  -- Changes section
  if #status_info.changes > 0 then
    table.insert(lines, "Working copy changes:")
    for _, change in ipairs(status_info.changes) do
      table.insert(lines, change.line)
    end
  else
    table.insert(lines, "The working copy has no changes.")
  end

  table.insert(lines, "")
  table.insert(lines, "# Commands:")
  table.insert(lines, "# cc = commit, new = create new change")
  table.insert(lines, "# dd = diff file, o = open file")
  table.insert(lines, "# r = reload status, q/gq = close")

  return lines
end

local function reload_status_content(bufnr)
  local output, err = get_jj_status()
  if not output then
    vim.api.nvim_err_writeln(err)
    return false
  end

  local status_info = parse_status_output(output)
  local lines = format_status_buffer(status_info)

  -- Update buffer content
  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

  return true
end
local function setup_buffer_keymaps(bufnr, status_info) -- luacheck: ignore status_info
  local opts = { noremap = true, silent = true, buffer = bufnr }

  -- Reload status
  vim.keymap.set("n", "r", function()
    -- Get current buffer for reload
    local current_buf = vim.api.nvim_get_current_buf()

    -- Only reload if we're in the status buffer
    local buf_name = vim.api.nvim_buf_get_name(current_buf)
    if buf_name:match("jj%-status$") then
      reload_status_content(current_buf)
    end
  end, opts)
  -- foo
  -- Commit current changes
  vim.keymap.set("n", "cc", function()
    local commit_msg = vim.fn.input("Commit message: ")
    if commit_msg and commit_msg ~= "" then
      vim.fn.system({ "jj", "commit", "-m", commit_msg })
      M.show_status()
    end
  end, opts)

  -- Create new change
  vim.keymap.set("n", "new", function()
    vim.fn.system({ "jj", "new" })
    M.show_status()
  end, opts)

  -- Diff file under cursor
  vim.keymap.set("n", "dd", function()
    local line = vim.api.nvim_get_current_line()
    local filename = line:match("^[A-Z] (.+)")
    if filename then
      require("jj-fugitive.diff").show_file_diff(filename)
    end
  end, opts)

  -- Open file under cursor
  vim.keymap.set("n", "o", function()
    local line = vim.api.nvim_get_current_line()
    local filename = line:match("^[A-Z] (.+)")
    if filename then
      -- Get the full path of the file
      local full_path = vim.fn.fnamemodify(filename, ":p")

      -- Check if the file is already open in any buffer
      local existing_bufnr = nil
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) then
          local buf_name = vim.api.nvim_buf_get_name(buf)
          if buf_name == full_path then
            existing_bufnr = buf
            break
          end
        end
      end

      if existing_bufnr then
        -- File is already open, find its window or create a new one
        local existing_win = nil
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          if vim.api.nvim_win_get_buf(win) == existing_bufnr then
            existing_win = win
            break
          end
        end

        if existing_win then
          -- Switch to the existing window
          vim.api.nvim_set_current_win(existing_win)
        else
          -- Buffer exists but no window is showing it, open it in current window
          vim.api.nvim_set_current_buf(existing_bufnr)
        end
      else
        -- File is not open, open it normally
        vim.cmd("edit " .. vim.fn.fnameescape(filename))
      end
    end
  end, opts)

  -- Close status buffer
  vim.keymap.set("n", "q", function()
    vim.cmd("close")
  end, opts)

  vim.keymap.set("n", "gq", function()
    vim.cmd("close")
  end, opts)
end

local function setup_buffer_highlighting(bufnr)
  vim.api.nvim_buf_call(bufnr, function()
    vim.cmd("syntax match JjStatusHeader '^#.*'")
    vim.cmd("syntax match JjStatusAdded '^A .*'")
    vim.cmd("syntax match JjStatusModified '^M .*'")
    vim.cmd("syntax match JjStatusDeleted '^D .*'")
    vim.cmd("syntax match JjStatusRenamed '^R .*'")

    vim.cmd("highlight default link JjStatusHeader Comment")
    vim.cmd("highlight default link JjStatusAdded DiffAdd")
    vim.cmd("highlight default link JjStatusModified DiffChange")
    vim.cmd("highlight default link JjStatusDeleted DiffDelete")
    vim.cmd("highlight default link JjStatusRenamed DiffChange")
  end)
end

function M.show_status()
  local output, err = get_jj_status()
  if not output then
    vim.api.nvim_err_writeln(err)
    return
  end

  local status_info = parse_status_output(output)
  local lines = format_status_buffer(status_info)

  local bufnr = get_or_create_status_buffer()

  -- Check if keymaps are already set up by looking for the 'r' mapping
  local existing_keymap = vim.fn.maparg("r", "n", false, true)
  local is_new_buffer = not existing_keymap or existing_keymap.buffer ~= 1

  -- Set buffer content
  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

  -- Setup keymaps and highlighting only for new buffers
  if is_new_buffer then
    setup_buffer_keymaps(bufnr, status_info)
    setup_buffer_highlighting(bufnr)
  end

  -- Open in current window or split
  local existing_win = nil
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == bufnr then
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

  -- Position cursor on the first file if there are changes
  if #status_info.changes > 0 then
    -- Find the line with the first file (lines start at 1)
    -- The format is: header, empty, working copy info, empty, "Working copy changes:", then files
    for i, line in ipairs(lines) do
      if line:match("^[A-Z] ") then -- First line that starts with a status character and space
        vim.api.nvim_win_set_cursor(0, { i, 0 })
        break
      end
    end
  end
end

return M
