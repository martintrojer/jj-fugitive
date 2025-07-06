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
  -- Use the main module's repository-aware command runner
  local main_module = require("jj-fugitive.init")
  local result = main_module.run_jj_command_from_module({ "status" })
  if not result then
    return nil, "Failed to get jj status"
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
  table.insert(lines, "# <CR> = show diff, o = open file, s = split, v = vsplit, t = tab")
  table.insert(
    lines,
    "# Tab = toggle diff view (inline/split), d = unified diff, D = side-by-side diff"
  )
  table.insert(lines, "# r = restore, a = absorb, cc = commit, ca = amend, l = log view")
  table.insert(lines, "# R = reload status, q = close, g? = help")

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

  -- Reload status (vim-fugitive uses R)
  vim.keymap.set("n", "R", function()
    -- Get current buffer for reload
    local current_buf = vim.api.nvim_get_current_buf()

    -- Only reload if we're in the status buffer
    local buf_name = vim.api.nvim_buf_get_name(current_buf)
    if buf_name:match("jj%-status$") then
      reload_status_content(current_buf)
    end
  end, opts)

  -- Commit current changes
  vim.keymap.set("n", "cc", function()
    local commit_msg = vim.fn.input("Commit message: ")
    if commit_msg and commit_msg ~= "" then
      local main_module = require("jj-fugitive.init")
      main_module.run_jj_command_from_module({ "commit", "-m", commit_msg })
      M.show_status()
    end
  end, opts)

  -- Commit amend (vim-fugitive ca)
  vim.keymap.set("n", "ca", function()
    local main_module = require("jj-fugitive.init")
    -- Get current commit description
    local current_desc = main_module.run_jj_command_from_module({
      "log",
      "-r",
      "@",
      "--no-graph",
      "-T",
      "description",
    })
    if current_desc then
      current_desc = current_desc:gsub("^%s*", ""):gsub("%s*$", "") -- trim whitespace
    end

    local commit_msg = vim.fn.input("Amend commit message: ", current_desc or "")
    if commit_msg and commit_msg ~= "" then
      main_module.run_jj_command_from_module({ "describe", "-m", commit_msg })
      vim.api.nvim_echo({ { "Amended commit description", "MoreMsg" } }, false, {})
      M.show_status()
    end
  end, opts)

  -- Commit extend (vim-fugitive ce) - add changes to current commit
  vim.keymap.set("n", "ce", function()
    local main_module = require("jj-fugitive.init")
    -- In jj, this is like doing a describe + commit in one step
    local commit_msg = vim.fn.input("Extend commit message: ")
    if commit_msg and commit_msg ~= "" then
      main_module.run_jj_command_from_module({ "commit", "-m", commit_msg })
      vim.api.nvim_echo({ { "Extended commit with changes", "MoreMsg" } }, false, {})
      M.show_status()
    end
  end, opts)

  -- Commit new (vim-fugitive cn) - create new commit after current
  vim.keymap.set("n", "cn", function()
    local main_module = require("jj-fugitive.init")
    main_module.run_jj_command_from_module({ "new" })
    vim.api.nvim_echo({ { "Created new commit", "MoreMsg" } }, false, {})
    M.show_status()
  end, opts)

  -- Create new change
  vim.keymap.set("n", "new", function()
    local main_module = require("jj-fugitive.init")
    main_module.run_jj_command_from_module({ "new" })
    M.show_status()
  end, opts)

  -- jj-idiomatic file operations (no staging area in jj)
  -- Note: jj automatically tracks all files, no manual tracking needed

  -- Restore file from parent revision (jj restore)
  vim.keymap.set("n", "r", function()
    local line = vim.api.nvim_get_current_line()
    local filename = line:match("^[A-Z] (.+)")
    if filename then
      -- Ask for confirmation since this will discard changes
      local choice = vim.fn.confirm(
        string.format(
          "Restore '%s' from parent revision? This will discard current changes.",
          filename
        ),
        "&Yes\n&No",
        2
      )
      if choice == 1 then
        local main_module = require("jj-fugitive.init")
        local result = main_module.run_jj_command_from_module({ "restore", filename })
        if result then
          vim.api.nvim_echo({ { "Restored: " .. filename, "MoreMsg" } }, false, {})
          M.show_status()
        end
      end
    end
  end, opts)

  -- Absorb changes into mutable ancestors (jj absorb)
  vim.keymap.set("n", "a", function()
    local line = vim.api.nvim_get_current_line()
    local filename = line:match("^[A-Z] (.+)")
    if filename then
      -- Ask for confirmation since this will modify commits
      local choice = vim.fn.confirm(
        string.format(
          "Absorb changes in '%s' into mutable ancestors? This will move changes to appropriate commits.",
          filename
        ),
        "&Yes\n&No",
        2
      )
      if choice == 1 then
        local main_module = require("jj-fugitive.init")
        local result = main_module.run_jj_command_from_module({ "absorb", filename })
        if result then
          vim.api.nvim_echo({ { "Absorbed changes: " .. filename, "MoreMsg" } }, false, {})
          M.show_status()
        end
      end
    else
      -- If no specific file, absorb all changes
      local choice = vim.fn.confirm(
        "Absorb all working copy changes into mutable ancestors? This will move changes to appropriate commits.",
        "&Yes\n&No",
        2
      )
      if choice == 1 then
        local main_module = require("jj-fugitive.init")
        local result = main_module.run_jj_command_from_module({ "absorb" })
        if result then
          vim.api.nvim_echo({ { "Absorbed all changes", "MoreMsg" } }, false, {})
          M.show_status()
        end
      end
    end
  end, opts)

  -- Unified diff view (replaces old D key)
  vim.keymap.set("n", "d", function()
    local line = vim.api.nvim_get_current_line()
    local filename = line:match("^[A-Z] (.+)")
    if filename then
      require("jj-fugitive.diff").show_file_diff(filename)
    end
  end, opts)

  -- Side-by-side diff view
  vim.keymap.set("n", "D", function()
    local line = vim.api.nvim_get_current_line()
    local filename = line:match("^[A-Z] (.+)")
    if filename then
      require("jj-fugitive.diff").show_file_diff_sidebyside(filename)
    end
  end, opts)

  -- Toggle between inline and split diff view
  vim.keymap.set("n", "<Tab>", function()
    local line = vim.api.nvim_get_current_line()
    local filename = line:match("^[A-Z] (.+)")
    if filename then
      require("jj-fugitive.diff").toggle_diff_view(filename)
    end
  end, opts)

  -- Open file under cursor (simple file opening)
  vim.keymap.set("n", "o", function()
    local line = vim.api.nvim_get_current_line()
    local filename = line:match("^[A-Z] (.+)")
    if filename then
      vim.cmd("edit " .. vim.fn.fnameescape(filename))
    end
  end, opts)

  -- Open file in horizontal split
  vim.keymap.set("n", "s", function()
    local line = vim.api.nvim_get_current_line()
    local filename = line:match("^[A-Z] (.+)")
    if filename then
      vim.cmd("split " .. vim.fn.fnameescape(filename))
    end
  end, opts)

  -- Open file in vertical split (replacing gO)
  vim.keymap.set("n", "v", function()
    local line = vim.api.nvim_get_current_line()
    local filename = line:match("^[A-Z] (.+)")
    if filename then
      vim.cmd("vsplit " .. vim.fn.fnameescape(filename))
    end
  end, opts)

  -- Open file in new tab (replacing O)
  vim.keymap.set("n", "t", function()
    local line = vim.api.nvim_get_current_line()
    local filename = line:match("^[A-Z] (.+)")
    if filename then
      vim.cmd("tabedit " .. vim.fn.fnameescape(filename))
    end
  end, opts)

  -- Close status buffer
  vim.keymap.set("n", "q", function()
    vim.cmd("close")
  end, opts)

  vim.keymap.set("n", "gq", function()
    vim.cmd("close")
  end, opts)

  -- Show diff for file under cursor or commit details for commit lines (vim-fugitive standard)
  vim.keymap.set("n", "<CR>", function()
    local line = vim.api.nvim_get_current_line()

    -- Check if it's a file change line (e.g., "M filename")
    local filename = line:match("^[A-Z] (.+)")
    if filename then
      require("jj-fugitive.diff").show_file_diff(filename)
      return
    end

    -- Check if it's a commit line and extract commit ID
    -- Pattern for "Working copy  (@) : changeid commitid description"
    -- We want the second hex string (commit ID), not the first (change ID)
    local commit_id = line:match("Working copy%s+%(@%)%s*:%s*%w+%s+([a-f0-9]+)")

    if not commit_id then
      -- Pattern for "Parent commit (@-): changeid commitid description"
      commit_id = line:match("Parent commit%s+%(@%-%):%s*%w+%s+([a-f0-9]+)")
    end

    if commit_id and #commit_id >= 8 then
      -- Show commit details using the log module
      require("jj-fugitive.log").show_commit_details(commit_id, { update_current = true })
    end
  end, opts)

  -- Launch log view (use 'l' for log)
  vim.keymap.set("n", "l", function()
    require("jj-fugitive.log").show_log()
  end, opts)

  -- Show help (vim-fugitive standard)
  vim.keymap.set("n", "g?", function()
    local help_lines = {
      "# jj-fugitive Status Window Help",
      "",
      "NOTE: jj automatically tracks all files (no staging area)",
      "Files are tracked immediately when created/modified.",
      "",
      "File operations:",
      "  <CR>    - Show diff for file",
      "  o       - Open file in editor",
      "  s       - Open file in horizontal split",
      "  v       - Open file in vertical split",
      "  t       - Open file in new tab",
      "  d       - Show unified diff for file",
      "  D       - Show side-by-side diff for file",
      "  Tab     - Toggle between unified/side-by-side diff",
      "",
      "jj file operations:",
      "  r       - Restore file from parent revision (jj restore)",
      "  a       - Absorb changes into mutable ancestors (jj absorb)",
      "            (moves changes to appropriate ancestor commits)",
      "",
      "jj workflow commands:",
      "  cc      - Commit working copy changes with message",
      "  ca      - Amend current commit description",
      "  ce      - Extend commit with current changes",
      "  cn      - Create new commit after current",
      "  new     - Create new working copy change",
      "",
      "Navigation & misc:",
      "  l       - Show log view (jj log)",
      "  R       - Reload status (refresh working copy state)",
      "  q       - Close status window",
      "  g?      - Show this help",
      "",
      "Press any key to close help...",
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
      title = " jj-fugitive Status Help ",
      title_pos = "center",
    }

    local help_win = vim.api.nvim_open_win(help_buf, true, win_opts)

    -- Close help on any key
    vim.keymap.set("n", "<CR>", function()
      vim.api.nvim_win_close(help_win, true)
    end, { buffer = help_buf, noremap = true, silent = true })

    vim.keymap.set("n", "<Esc>", function()
      vim.api.nvim_win_close(help_win, true)
    end, { buffer = help_buf, noremap = true, silent = true })

    -- Close on any other key
    for _, key in ipairs({ "q", "g", "?", "o", "D", "l", "R" }) do
      vim.keymap.set("n", key, function()
        vim.api.nvim_win_close(help_win, true)
      end, { buffer = help_buf, noremap = true, silent = true })
    end
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

  -- Check if keymaps are already set up by looking for the 'R' mapping (changed from 'r')
  local existing_keymap = vim.fn.maparg("R", "n", false, true)
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
