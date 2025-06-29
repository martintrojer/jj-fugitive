local M = {}

-- Get log output from jj with enhanced formatting
local function get_jj_log(options)
  options = options or {}

  -- Use the main module's repository-aware command runner
  local main_module = require("jj-fugitive.init")

  local cmd_args = { "log" }

  -- Use a custom template for better formatting
  table.insert(cmd_args, "--template")
  table.insert(
    cmd_args,
    'change_id.short() ++ " | " ++ if(description, description.first_line(), "(no description)") ++ " | " ++ author.email() ++ " | " ++ committer.timestamp().ago()'
  )

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

-- Parse log output into structured data
local function parse_log_output(output)
  local lines = vim.split(output, "\n")
  local commits = {}

  for _, line in ipairs(lines) do
    if line ~= "" then
      -- Parse the custom template format: commit_id | description | author | time
      local commit_id, description, author, time =
        line:match("^([^|]+) | ([^|]+) | ([^|]+) | (.+)$")
      if commit_id then
        table.insert(commits, {
          id = vim.trim(commit_id),
          description = vim.trim(description),
          author = vim.trim(author),
          time = vim.trim(time),
          full_line = line,
        })
      end
    end
  end

  return commits
end

-- Enhanced log content formatting with visual indicators
local function format_log_content(commits)
  local lines = {}

  -- Add header
  table.insert(lines, "")
  table.insert(lines, "📜 jj Log View - Repository History")
  table.insert(lines, "🔍 Navigate with j/k, press Enter to show commit, ? for help")
  table.insert(lines, string.rep("─", 80))
  table.insert(lines, "")

  -- Add column headers
  table.insert(
    lines,
    "📋 Commit ID        | Description                           | Author      | Time"
  )
  table.insert(lines, string.rep("─", 80))

  -- Format each commit with visual indicators
  for _, commit in ipairs(commits) do
    local icon = "📝"

    -- Special icons for certain commits
    if commit.id:match("^@") then
      icon = "👉" -- Current working copy
    elseif commit.description:match("^Merge") then
      icon = "🔀" -- Merge commit
    elseif commit.description:match("^Initial") or commit.description:match("^initial") then
      icon = "🌱" -- Initial commit
    elseif commit.description:match("^Fix") or commit.description:match("^fix") then
      icon = "🔧" -- Fix commit
    elseif commit.description:match("^Add") or commit.description:match("^add") then
      icon = "➕" -- Add commit
    elseif commit.description:match("^Remove") or commit.description:match("^remove") then
      icon = "➖" -- Remove commit
    end

    -- Format commit line with proper spacing
    local short_id = commit.id:sub(1, 8)
    local short_desc = commit.description:sub(1, 35)
    if #commit.description > 35 then
      short_desc = short_desc .. "..."
    end
    local short_author = commit.author:sub(1, 10)
    if #commit.author > 10 then
      short_author = short_author .. "..."
    end

    local formatted_line = string.format(
      "%s %s | %-35s | %-10s | %s",
      icon,
      short_id,
      short_desc,
      short_author,
      commit.time
    )
    table.insert(lines, formatted_line)
  end

  table.insert(lines, "")
  table.insert(lines, string.rep("─", 80))
  table.insert(lines, "")
  table.insert(lines, "💡 Commands:")
  table.insert(lines, "   Enter/o = Show commit details    e = Edit at commit")
  table.insert(lines, "   n = New commit after this       r = Rebase onto this commit")
  table.insert(lines, "   d = Show diff for commit        q = Close log view")
  table.insert(lines, "   ? = Show detailed help")

  return lines
end

-- Setup enhanced log highlighting
local function setup_log_highlighting(bufnr)
  vim.api.nvim_buf_call(bufnr, function()
    -- Clear existing syntax
    vim.cmd("syntax clear")

    -- Header highlighting
    vim.cmd("syntax match JjLogHeader '^📜.*$'")
    vim.cmd("syntax match JjLogSubHeader '^🔍.*$'")
    vim.cmd("syntax match JjLogSeparator '^─\\+$'")
    vim.cmd("syntax match JjLogColumnHeader '^📋.*$'")
    vim.cmd("syntax match JjLogHelp '^💡.*$'")
    vim.cmd("syntax match JjLogHelpDetail '^   .*$'")

    -- Commit line highlighting with icons
    vim.cmd("syntax match JjLogCurrentCommit '^👉.*$'")
    vim.cmd("syntax match JjLogMergeCommit '^🔀.*$'")
    vim.cmd("syntax match JjLogInitialCommit '^🌱.*$'")
    vim.cmd("syntax match JjLogFixCommit '^🔧.*$'")
    vim.cmd("syntax match JjLogAddCommit '^➕.*$'")
    vim.cmd("syntax match JjLogRemoveCommit '^➖.*$'")
    vim.cmd("syntax match JjLogRegularCommit '^📝.*$'")

    -- Apply colors
    vim.cmd("highlight default JjLogHeader ctermfg=14 guifg=Cyan cterm=bold gui=bold")
    vim.cmd("highlight default JjLogSubHeader ctermfg=8 guifg=Gray cterm=italic gui=italic")
    vim.cmd("highlight default JjLogSeparator ctermfg=8 guifg=Gray")
    vim.cmd("highlight default JjLogColumnHeader ctermfg=11 guifg=Yellow cterm=bold gui=bold")
    vim.cmd("highlight default JjLogHelp ctermfg=10 guifg=LightGreen cterm=bold gui=bold")
    vim.cmd("highlight default JjLogHelpDetail ctermfg=7 guifg=LightGray")

    -- Commit type colors
    vim.cmd("highlight default JjLogCurrentCommit ctermfg=13 guifg=Magenta cterm=bold gui=bold")
    vim.cmd("highlight default JjLogMergeCommit ctermfg=12 guifg=LightBlue cterm=bold gui=bold")
    vim.cmd("highlight default JjLogInitialCommit ctermfg=10 guifg=LightGreen cterm=bold gui=bold")
    vim.cmd("highlight default JjLogFixCommit ctermfg=9 guifg=LightRed")
    vim.cmd("highlight default JjLogAddCommit ctermfg=10 guifg=LightGreen")
    vim.cmd("highlight default JjLogRemoveCommit ctermfg=9 guifg=LightRed")
    vim.cmd("highlight default JjLogRegularCommit ctermfg=7 guifg=LightGray")
  end)
end

-- Get commit ID from current line
local function get_commit_from_line(line)
  -- Extract commit ID from formatted line
  -- Format: "icon revision_symbol actual_commit_id | description | author | time"
  -- Extract the part before the first pipe, then get the last token
  local first_part = line:match("^([^|]+)")
  if first_part then
    first_part = vim.trim(first_part)

    -- Skip header lines (they contain column headers)
    if first_part:match("Commit ID") or first_part:match("Description") then
      return nil
    end

    -- Get all tokens and take the last one (which should be the commit ID)
    local tokens = {}
    for token in first_part:gmatch("%S+") do
      table.insert(tokens, token)
    end
    if #tokens >= 3 then -- icon, revision_symbol, commit_id
      return tokens[#tokens] -- Last token is the commit ID
    end
  end
  return nil
end

-- Show commit details
local function show_commit_details(commit_id)
  if not commit_id then
    vim.api.nvim_echo({ { "No commit selected", "WarningMsg" } }, false, {})
    return
  end

  -- Get commit details using repository-aware command
  local main_module = require("jj-fugitive.init")
  local result = main_module.run_jj_command_from_module({ "show", commit_id })
  if not result then
    return
  end

  -- Create buffer for commit details
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  vim.api.nvim_buf_set_name(bufnr, "jj-show: " .. commit_id)

  -- Enhanced commit details formatting
  local header_lines = {
    "",
    "📄 Commit Details: " .. commit_id,
    string.rep("─", 60),
    "",
  }

  local content_lines = vim.split(result, "\n")
  local all_lines = {}

  -- Add header
  for _, line in ipairs(header_lines) do
    table.insert(all_lines, line)
  end

  -- Add content
  for _, line in ipairs(content_lines) do
    table.insert(all_lines, line)
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, all_lines)
  vim.api.nvim_buf_set_option(bufnr, "filetype", "diff")
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

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

-- Show diff for commit
local function show_commit_diff(commit_id)
  if not commit_id then
    vim.api.nvim_echo({ { "No commit selected", "WarningMsg" } }, false, {})
    return
  end

  -- Show diff for commit using repository-aware command
  local main_module = require("jj-fugitive.init")
  local result = main_module.run_jj_command_from_module({ "diff", "-r", commit_id })
  if not result then
    return
  end

  -- Create enhanced diff buffer
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  vim.api.nvim_buf_set_name(bufnr, "jj-diff: " .. commit_id)

  -- Enhanced diff formatting
  local header_lines = {
    "",
    "📄 Commit Diff: " .. commit_id,
    "🔄 Changes in this commit",
    string.rep("─", 60),
    "",
  }

  local content_lines = vim.split(result, "\n")
  local all_lines = {}

  -- Add header
  for _, line in ipairs(header_lines) do
    table.insert(all_lines, line)
  end

  -- Add content
  for _, line in ipairs(content_lines) do
    table.insert(all_lines, line)
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, all_lines)
  vim.api.nvim_buf_set_option(bufnr, "filetype", "diff")
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

  -- Open in new window
  vim.cmd("split")
  vim.api.nvim_set_current_buf(bufnr)

  -- Setup close keymap
  vim.keymap.set("n", "q", function()
    vim.cmd("close")
  end, { buffer = bufnr, noremap = true, silent = true })
end

-- Setup log buffer keymaps
local function setup_log_keymaps(bufnr)
  local opts = { noremap = true, silent = true, buffer = bufnr }

  -- Show commit details
  vim.keymap.set("n", "<CR>", function()
    local line = vim.api.nvim_get_current_line()
    local commit_id = get_commit_from_line(line)
    show_commit_details(commit_id)
  end, opts)

  vim.keymap.set("n", "o", function()
    local line = vim.api.nvim_get_current_line()
    local commit_id = get_commit_from_line(line)
    show_commit_details(commit_id)
  end, opts)

  -- Edit at commit
  vim.keymap.set("n", "e", function()
    local line = vim.api.nvim_get_current_line()
    local commit_id = get_commit_from_line(line)
    edit_at_commit(commit_id)
  end, opts)

  -- New commit after this one
  vim.keymap.set("n", "n", function()
    local line = vim.api.nvim_get_current_line()
    local commit_id = get_commit_from_line(line)
    new_after_commit(commit_id)
  end, opts)

  -- Rebase onto commit
  vim.keymap.set("n", "r", function()
    local line = vim.api.nvim_get_current_line()
    local commit_id = get_commit_from_line(line)
    rebase_onto_commit(commit_id)
  end, opts)

  -- Show diff for commit
  vim.keymap.set("n", "d", function()
    local line = vim.api.nvim_get_current_line()
    local commit_id = get_commit_from_line(line)
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

  -- Show help
  vim.keymap.set("n", "?", function()
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
      "  ?         - Show this help",
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

  local commits = parse_log_output(log_output)
  if #commits == 0 then
    vim.api.nvim_echo({ { "No commits found", "WarningMsg" } }, false, {})
    return
  end

  local lines = format_log_content(commits)

  -- Create or reuse log buffer
  local bufnr = nil
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      if name:match("jj%-log$") then
        bufnr = buf
        break
      end
    end
  end

  if not bufnr then
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
    vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
    vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
    vim.api.nvim_buf_set_name(bufnr, "jj-log")
  end

  -- Set content
  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

  -- Setup highlighting and keymaps
  setup_log_highlighting(bufnr)
  setup_log_keymaps(bufnr)

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
  for i, line in ipairs(lines) do
    -- Match actual commit lines: lines with pipes that can extract valid commit IDs
    if line:match("|") then
      local first_part = line:match("^([^|]+)")
      if first_part then
        first_part = vim.trim(first_part)

        -- Skip header lines
        if not (first_part:match("Commit ID") or first_part:match("Description")) then
          local tokens = {}
          for token in first_part:gmatch("%S+") do
            table.insert(tokens, token)
          end
          -- Real commit lines have at least 3 tokens: icon, revision_symbol, commit_id
          if #tokens >= 3 then
            vim.api.nvim_win_set_cursor(0, { i, 0 })
            break
          end
        end
      end
    end
  end

  -- Set status line
  vim.api.nvim_buf_call(bufnr, function()
    vim.cmd("setlocal statusline=jj-log:\\ Repository\\ History")
  end)
end

return M
