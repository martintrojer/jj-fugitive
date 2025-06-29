local M = {}

-- Import shared ANSI parsing utilities
local ansi = require("jj-fugitive.ansi")

-- Get native jj log output with colors preserved
local function get_jj_log(options)
  options = options or {}

  -- Use the main module's repository-aware command runner
  local main_module = require("jj-fugitive.init")

  local cmd_args = { "log" }

  -- Add color support to get native jj formatting
  table.insert(cmd_args, "--color")
  table.insert(cmd_args, "always")

  -- Limit number of commits if specified
  if options.limit then
    table.insert(cmd_args, "--limit")
    table.insert(cmd_args, tostring(options.limit))
  end

  -- Add revisions if specified
  if options.revisions then
    for _, rev in ipairs(options.revisions) do
      table.insert(cmd_args, "--revisions")
      table.insert(cmd_args, rev)
    end
  end

  -- Use the main module's run_jj_command function for proper repository handling
  local result = main_module.run_jj_command_from_module(cmd_args)
  if not result then
    return nil, "Failed to get log"
  end
  return result, nil
end

-- Extract commit IDs from native jj log output
local function extract_commit_ids_from_log(output)
  local lines = vim.split(output, "\n")
  local commit_data = {}

  for i, line in ipairs(lines) do
    if line ~= "" then
      -- Strip ANSI codes using the shared ANSI module
      local clean_line, _ = ansi.parse_ansi_colors(line)

      -- Extract commit ID from clean jj log format
      -- Look for patterns like: @ yxmkqymr ... e10e058e
      -- or: ◆ movyorsy ... main 92709b0c
      local commit_id

      -- Try to extract commit ID (8-character hex at end or after bookmark)
      -- Pattern: any non-space followed by 8 hex chars at line end
      commit_id = clean_line:match("[%w]+%s+([a-f0-9]+)$")

      if not commit_id then
        -- Try pattern with bookmark: main 92709b0c
        commit_id = clean_line:match("%s+[%w%-_]+%s+([a-f0-9]+)$")
      end

      if not commit_id then
        -- Try simpler pattern: 8 hex chars at end
        commit_id =
          clean_line:match("([a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9])$")
      end

      if commit_id and #commit_id == 8 then
        table.insert(commit_data, {
          line_number = i,
          commit_id = commit_id,
          original_line = line, -- Keep original line with ANSI codes for display
          clean_line = clean_line,
        })
      end
    end
  end

  return commit_data
end

-- Get commit ID from current line in native jj log format
local function get_commit_from_line(line, commit_data)
  -- Skip header lines
  if line:match("^#") or line == "" then
    return nil
  end

  -- Find the commit data for this line by matching content
  for _, data in ipairs(commit_data or {}) do
    if data.original_line == line then
      return data.commit_id
    end
  end

  -- Fallback: try to extract directly from line
  -- Look for 8-character hex at end of line
  local commit_id =
    line:match("([a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9])$")
  return commit_id
end

-- Show commit details with consistent diff formatting
local function show_commit_details(commit_id)
  if not commit_id then
    vim.api.nvim_echo({ { "No commit selected", "WarningMsg" } }, false, {})
    return
  end

  -- Get commit details using repository-aware command with color and git format
  local main_module = require("jj-fugitive.init")
  local result =
    main_module.run_jj_command_from_module({ "show", "--color", "always", "--git", commit_id })
  if not result then
    return
  end

  -- Create header lines consistent with diff view
  local header_lines = {
    "",
    "# Commit: " .. commit_id,
    "# Details and changes for this commit",
    "",
  }

  local bufname = string.format("jj-show: %s", commit_id)

  -- Use shared utility to create colored buffer with consistent formatting
  local bufnr = ansi.create_colored_buffer(result, bufname, header_lines, {
    prefix = "JjShow",
    custom_syntax = {
      ["^# Commit:.*$"] = "JjShowHeader",
      ["^# Details.*$"] = "JjShowSubHeader",
    },
  })

  -- Open in new window
  vim.cmd("split")
  vim.api.nvim_set_current_buf(bufnr)

  -- Setup close keymap
  vim.keymap.set("n", "q", function()
    vim.cmd("close")
  end, { buffer = bufnr, noremap = true, silent = true })
end

-- Edit at commit (jj edit)
local function edit_at_commit(commit_id)
  if not commit_id then
    vim.api.nvim_echo({ { "No commit selected", "WarningMsg" } }, false, {})
    return
  end

  local main_module = require("jj-fugitive.init")
  local result = main_module.run_jj_command_from_module({ "edit", commit_id })
  if not result then
    return
  end

  vim.api.nvim_echo({ { "Editing at commit " .. commit_id, "MoreMsg" } }, false, {})
  -- Refresh the log view
  M.show_log()
end

-- Create new commit after selected commit (jj new)
local function new_after_commit(commit_id)
  if not commit_id then
    vim.api.nvim_echo({ { "No commit selected", "WarningMsg" } }, false, {})
    return
  end

  local main_module = require("jj-fugitive.init")
  local result = main_module.run_jj_command_from_module({ "new", commit_id })
  if not result then
    return
  end

  vim.api.nvim_echo({ { "Created new commit after " .. commit_id, "MoreMsg" } }, false, {})
  -- Refresh the log view
  M.show_log()
end

-- Rebase onto commit (jj rebase)
local function rebase_onto_commit(commit_id)
  if not commit_id then
    vim.api.nvim_echo({ { "No commit selected", "WarningMsg" } }, false, {})
    return
  end

  -- Ask for confirmation
  local choice = vim.fn.confirm("Rebase current commit onto " .. commit_id .. "?", "&Yes\n&No", 2)
  if choice ~= 1 then
    return
  end

  local main_module = require("jj-fugitive.init")
  local result = main_module.run_jj_command_from_module({ "rebase", "-d", commit_id })
  if not result then
    return
  end

  vim.api.nvim_echo({ { "Rebased onto " .. commit_id, "MoreMsg" } }, false, {})
  -- Refresh the log view
  M.show_log()
end

-- Show diff for commit with consistent formatting to regular diff view
local function show_commit_diff(commit_id)
  if not commit_id then
    vim.api.nvim_echo({ { "No commit selected", "WarningMsg" } }, false, {})
    return
  end

  -- Show diff for commit using repository-aware command with color and git format
  local main_module = require("jj-fugitive.init")
  local result = main_module.run_jj_command_from_module({
    "diff",
    "--color",
    "always",
    "--git",
    "-r",
    commit_id,
  })
  if not result then
    return
  end

  -- Create header lines consistent with regular diff view format
  local header_lines = {
    "",
    "# Commit Diff: " .. commit_id,
    "# Changes in this commit vs parent",
    "",
  }

  local bufname = string.format("jj-diff: %s", commit_id)

  -- Use shared utility to create colored buffer with consistent formatting
  local bufnr = ansi.create_colored_buffer(result, bufname, header_lines, {
    prefix = "JjDiff", -- Use same prefix as regular diff view for consistency
    custom_syntax = {
      ["^# Commit Diff:.*$"] = "JjDiffFileHeader",
      ["^# Changes.*$"] = "JjDiffChangeHeader",
    },
  })

  -- Open in new window
  vim.cmd("split")
  vim.api.nvim_set_current_buf(bufnr)

  -- Setup close keymap
  vim.keymap.set("n", "q", function()
    vim.cmd("close")
  end, { buffer = bufnr, noremap = true, silent = true })
end

-- Setup log buffer keymaps
local function setup_log_keymaps(bufnr, commit_data)
  local opts = { noremap = true, silent = true, buffer = bufnr }

  -- Show commit details
  vim.keymap.set("n", "<CR>", function()
    local line = vim.api.nvim_get_current_line()
    local commit_id = get_commit_from_line(line, commit_data)
    show_commit_details(commit_id)
  end, opts)

  vim.keymap.set("n", "o", function()
    local line = vim.api.nvim_get_current_line()
    local commit_id = get_commit_from_line(line, commit_data)
    show_commit_details(commit_id)
  end, opts)

  -- Edit at commit
  vim.keymap.set("n", "e", function()
    local line = vim.api.nvim_get_current_line()
    local commit_id = get_commit_from_line(line, commit_data)
    edit_at_commit(commit_id)
  end, opts)

  -- New commit after this one
  vim.keymap.set("n", "n", function()
    local line = vim.api.nvim_get_current_line()
    local commit_id = get_commit_from_line(line, commit_data)
    new_after_commit(commit_id)
  end, opts)

  -- Rebase onto commit
  vim.keymap.set("n", "r", function()
    local line = vim.api.nvim_get_current_line()
    local commit_id = get_commit_from_line(line, commit_data)
    rebase_onto_commit(commit_id)
  end, opts)

  -- Show diff for commit
  vim.keymap.set("n", "d", function()
    local line = vim.api.nvim_get_current_line()
    local commit_id = get_commit_from_line(line, commit_data)
    show_commit_diff(commit_id)
  end, opts)

  -- Close log view
  vim.keymap.set("n", "q", function()
    vim.cmd("close")
  end, opts)

  -- Refresh log
  vim.keymap.set("n", "R", function()
    M.show_log()
  end, opts)

  -- Show help (vim-fugitive standard)
  vim.keymap.set("n", "g?", function()
    local help_lines = {
      "# jj-fugitive Log View Help",
      "",
      "Navigation:",
      "  j/k       - Move up/down through commits",
      "  gg/G      - Go to first/last commit",
      "",
      "Commit Actions:",
      "  Enter/o   - Show commit details and changes",
      "  e         - Edit at this commit (jj edit)",
      "  n         - Create new commit after this one (jj new)",
      "  r         - Rebase current commit onto this one (jj rebase)",
      "  d         - Show diff for this commit",
      "",
      "View Actions:",
      "  R         - Refresh log view",
      "  q         - Close log view",
      "  g?        - Show this help",
      "",
      "Visual Indicators:",
      "  👉        - Current working copy",
      "  🔀        - Merge commit",
      "  🌱        - Initial commit",
      "  🔧        - Fix commit",
      "  ➕        - Add commit",
      "  ➖        - Remove commit",
      "  📝        - Regular commit",
      "",
      "Press any key to continue...",
    }

    local help_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(help_buf, 0, -1, false, help_lines)
    vim.api.nvim_buf_set_option(help_buf, "modifiable", false)
    vim.api.nvim_buf_set_option(help_buf, "filetype", "markdown")

    local win_width = vim.api.nvim_get_option("columns")
    local win_height = vim.api.nvim_get_option("lines")
    local width = math.min(70, win_width - 4)
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

-- Main function to show log view
function M.show_log(options)
  options = options or { limit = 50 }

  local log_output, err = get_jj_log(options)
  if not log_output then
    vim.api.nvim_err_writeln(err)
    return
  end

  -- Extract commit data for interactive features
  local commit_data = extract_commit_ids_from_log(log_output)
  if #commit_data == 0 then
    vim.api.nvim_echo({ { "No commits found", "WarningMsg" } }, false, {})
    return
  end

  -- Use native jj output with ANSI processing
  local header_lines = {
    "",
    "# jj Log View",
    "# Navigate: j/k, Enter=show commit, d=diff, e=edit, n=new, r=rebase, q=quit, ?=help",
    "",
  }

  -- Create buffer with native jj log output and ANSI color processing
  local bufname = "jj-log"
  local bufnr = ansi.create_colored_buffer(log_output, bufname, header_lines, {
    prefix = "JjLog",
    custom_syntax = {
      ["^# jj Log View$"] = "JjLogHeader",
      ["^# Navigate:.*$"] = "JjLogSubHeader",
    },
  })

  -- Apply custom header highlighting after buffer creation
  vim.api.nvim_buf_call(bufnr, function()
    vim.cmd("highlight default JjLogHeader ctermfg=14 guifg=Cyan cterm=bold gui=bold")
    vim.cmd("highlight default JjLogSubHeader ctermfg=8 guifg=Gray cterm=italic gui=italic")
  end)

  -- Setup keymaps for interaction
  setup_log_keymaps(bufnr, commit_data)

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

  -- Position cursor on first commit line (skip headers)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for i, line in ipairs(lines) do
    -- Look for the first actual commit line (not header)
    if not line:match("^#") and line ~= "" and get_commit_from_line(line, commit_data) then
      vim.api.nvim_win_set_cursor(0, { i, 0 })
      break
    end
  end

  -- Set status line
  vim.api.nvim_buf_call(bufnr, function()
    vim.cmd("setlocal statusline=jj-log:\\ Repository\\ History")
  end)
end

return M
