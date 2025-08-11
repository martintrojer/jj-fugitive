local M = {}

-- Import shared ANSI parsing utilities
local ansi = require("jj-fugitive.ansi")

-- Forward declaration for side-by-side diff function
local show_commit_diff_sidebyside

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

  -- Add revisions if specified (supports -r flag)
  if options.revisions then
    for _, rev in ipairs(options.revisions) do
      table.insert(cmd_args, "-r")
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

      if commit_id and #commit_id >= 8 then
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

-- Setup keymaps for commit detail view with navigation back to log
local function setup_commit_detail_keymaps(bufnr)
  local ui = require("jj-fugitive.ui")

  -- Back to previous view (log or status)
  ui.map(bufnr, "n", "b", function()
    local has_previous = pcall(vim.api.nvim_buf_get_var, bufnr, "jj_previous_view")
    if has_previous then
      local previous_view = vim.api.nvim_buf_get_var(bufnr, "jj_previous_view")
      if previous_view == "status" then
        -- Go back to status view
        require("jj-fugitive.status").show_status()
      else
        -- Go back to log view (default behavior)
        local log_limit = vim.api.nvim_buf_get_var(bufnr, "jj_log_limit")
        M.show_log({ limit = log_limit, update_current = true })
      end
    else
      M.show_log({ update_current = true })
    end
  end)

  -- Quit
  ui.map(bufnr, "n", "q", function()
    vim.cmd("bdelete!")
  end)
end

-- Show commit details with consistent diff formatting
local function show_commit_details(commit_id, opts)
  opts = opts or {}

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
    "# Press 'b' to go back to log view, 'q' to quit",
    "",
  }

  local bufname = string.format("jj-show: %s", commit_id)

  -- If update_current is true, update the current buffer instead of creating new window
  if opts.update_current then
    local current_bufnr = vim.api.nvim_get_current_buf()
    -- Only update if we're in a jj-related buffer
    if require("jj-fugitive.ui").is_jj_buffer(current_bufnr) then
      -- Store original buffer info for navigation back
      local previous_view = opts.previous_view or "log"
      vim.api.nvim_buf_set_var(current_bufnr, "jj_previous_view", previous_view)
      local log_limit = 0 -- Default to no limit (standard jj log)
      pcall(function()
        log_limit = vim.api.nvim_buf_get_var(current_bufnr, "jj_log_limit")
      end)
      vim.api.nvim_buf_set_var(current_bufnr, "jj_log_limit", log_limit)

      -- Update buffer content
      ansi.update_colored_buffer(current_bufnr, result, header_lines, {
        prefix = "JjShow",
        custom_syntax = {
          ["^# Commit:.*$"] = "JjShowHeader",
          ["^# Details.*$"] = "JjShowSubHeader",
        },
      })

      -- Update buffer name
      vim.api.nvim_buf_set_name(current_bufnr, bufname)

      -- Setup navigation keymaps
      setup_commit_detail_keymaps(current_bufnr)
      return
    end
  end

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

  -- Setup navigation keymaps
  setup_commit_detail_keymaps(bufnr)
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
  M.show_log({ update_current = true })
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
  M.show_log({ update_current = true })
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
  M.show_log({ update_current = true })
end

-- Show diff for commit with consistent formatting to regular diff view
local function show_commit_diff(commit_id, opts)
  opts = opts or {}

  if not commit_id then
    vim.api.nvim_echo({ { "No commit selected", "WarningMsg" } }, false, {})
    return
  end

  -- For side-by-side diff, we need to handle it differently
  if opts.sidebyside then
    show_commit_diff_sidebyside(commit_id)
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
    "# Press 'b' to go back to log view, 'q' to quit",
    "",
  }

  local bufname = string.format("jj-diff: %s", commit_id)

  -- If update_current is true, update the current buffer instead of creating new window
  if opts.update_current then
    local current_bufnr = vim.api.nvim_get_current_buf()
    -- Only update if we're in a jj-related buffer
    if require("jj-fugitive.ui").is_jj_buffer(current_bufnr) then
      -- Store original buffer info for navigation back
      local previous_view = opts.previous_view or "log"
      vim.api.nvim_buf_set_var(current_bufnr, "jj_previous_view", previous_view)
      local log_limit = 0 -- Default to no limit (standard jj log)
      pcall(function()
        log_limit = vim.api.nvim_buf_get_var(current_bufnr, "jj_log_limit")
      end)
      vim.api.nvim_buf_set_var(current_bufnr, "jj_log_limit", log_limit)

      -- Update buffer content
      ansi.update_colored_buffer(current_bufnr, result, header_lines, {
        prefix = "JjDiff",
        custom_syntax = {
          ["^# Commit Diff:.*$"] = "JjDiffFileHeader",
          ["^# Changes.*$"] = "JjDiffChangeHeader",
        },
      })

      -- Update buffer name
      vim.api.nvim_buf_set_name(current_bufnr, bufname)

      -- Setup navigation keymaps
      setup_commit_detail_keymaps(current_bufnr)
      return
    end
  end

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

  -- Setup navigation keymaps
  setup_commit_detail_keymaps(bufnr)
end

-- Show side-by-side diff for commit
function show_commit_diff_sidebyside(commit_id)
  if not commit_id then
    vim.api.nvim_echo({ { "No commit selected", "WarningMsg" } }, false, {})
    return
  end

  -- Get the list of files changed in this commit
  local main_module = require("jj-fugitive.init")
  local files_result = main_module.run_jj_command_from_module({
    "diff",
    "--name-only",
    "-r",
    commit_id,
  })

  if not files_result or files_result:match("^%s*$") then
    vim.api.nvim_echo({ { "No files changed in commit " .. commit_id, "WarningMsg" } }, false, {})
    return
  end

  -- Get the first changed file for side-by-side view
  local files = vim.split(files_result, "\n")
  local first_file = nil
  for _, file in ipairs(files) do
    if file:match("%S") then -- non-empty line
      first_file = file
      break
    end
  end

  if not first_file then
    vim.api.nvim_echo(
      { { "No valid files found in commit " .. commit_id, "WarningMsg" } },
      false,
      {}
    )
    return
  end

  -- Show side-by-side diff for the first file in this commit
  vim.api.nvim_echo({
    { "Side-by-side diff for commit " .. commit_id, "MoreMsg" },
    { " (file: " .. first_file .. ")", "Comment" },
  }, false, {})

  -- Get file content at the commit and its parent
  local commit_content = main_module.run_jj_command_from_module({
    "file",
    "show",
    first_file,
    "-r",
    commit_id,
  })

  local parent_content = main_module.run_jj_command_from_module({
    "file",
    "show",
    first_file,
    "-r",
    commit_id .. "-",
  })

  -- Handle case where file is new or deleted
  if not parent_content then
    parent_content = "" -- File was newly added
  end
  if not commit_content then
    commit_content = "" -- File was deleted
  end

  -- Create side-by-side buffers in a new tab
  vim.cmd("tabnew")

  -- Left buffer (parent/before)
  local left_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(left_bufnr, string.format("%s@%s- (parent)", first_file, commit_id))
  vim.api.nvim_buf_set_lines(left_bufnr, 0, -1, false, vim.split(parent_content, "\n"))
  vim.api.nvim_buf_set_option(left_bufnr, "modifiable", false)
  vim.api.nvim_buf_set_option(left_bufnr, "readonly", true)

  -- Right buffer (commit/after)
  local right_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(right_bufnr, string.format("%s@%s (commit)", first_file, commit_id))
  vim.api.nvim_buf_set_lines(right_bufnr, 0, -1, false, vim.split(commit_content, "\n"))
  vim.api.nvim_buf_set_option(right_bufnr, "modifiable", false)
  vim.api.nvim_buf_set_option(right_bufnr, "readonly", true)

  -- Set up side-by-side layout
  vim.cmd("vsplit")
  vim.api.nvim_set_current_buf(left_bufnr)
  vim.cmd("wincmd l")
  vim.api.nvim_set_current_buf(right_bufnr)

  -- Enable diff mode for both buffers
  vim.cmd("wincmd h")
  vim.cmd("diffthis")
  vim.cmd("wincmd l")
  vim.cmd("diffthis")

  -- Set up keymaps for both buffers
  local function setup_commit_diff_keymaps(bufnr)
    local ui = require("jj-fugitive.ui")
    ui.map(bufnr, "n", "q", function()
      vim.cmd("tabclose")
    end)
    ui.map(bufnr, "n", "b", function()
      vim.cmd("tabclose")
    end)
  end

  setup_commit_diff_keymaps(left_bufnr)
  setup_commit_diff_keymaps(right_bufnr)
end

-- Expand log view with more commits using -r .. flag with increased limit
local function expand_log_view(bufnr)
  -- Get current limit from buffer variable
  -- If no limit was set initially (standard jj log), start with 50 and expand
  local current_limit = vim.api.nvim_buf_get_var(bufnr, "jj_log_limit") or 0
  local new_limit = current_limit == 0 and 50 or current_limit + 50

  -- Get current cursor position to restore it
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local current_line = vim.api.nvim_get_current_line()

  -- Show message to user
  vim.api.nvim_echo(
    { { string.format("Expanding log view to %d commits...", new_limit), "MoreMsg" } },
    false,
    {}
  )

  -- Get new log output using -r .. with increased limit to show more commits
  local log_output, err = get_jj_log({ revisions = { ".." }, limit = new_limit })
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

  -- Check if we actually got more commits
  local current_commit_count = 0
  local current_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for _, line in ipairs(current_lines) do
    if not line:match("^#") and line ~= "" and line:match("[◆@○]") then
      current_commit_count = current_commit_count + 1
    end
  end

  if #commit_data <= current_commit_count then
    vim.api.nvim_echo({
      { string.format("Already showing all %d commits available", #commit_data), "WarningMsg" },
    }, false, {})
    return
  end

  -- Update header with new count
  local header_lines = {
    "",
    string.format("# jj Log View (showing %d commits)", new_limit),
    "# Navigate: j/k, P/N=parent/next, Enter=details, d=diff, D=side-by-side, Tab=toggle, e=edit, +=expand, q=quit, g?=help",
    "",
  }

  -- Process the new content using ANSI module
  local processed_lines, all_highlights = ansi.process_diff_content(log_output, header_lines)

  -- Update buffer content in-place
  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, processed_lines)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

  -- Apply highlights
  ansi.setup_diff_highlighting(bufnr, all_highlights, {
    prefix = "JjLog",
    custom_syntax = {
      ["^# jj Log View$"] = "JjLogHeader",
      ["^# Navigate:.*$"] = "JjLogSubHeader",
    },
  })

  -- Update buffer variable with new limit
  vim.api.nvim_buf_set_var(bufnr, "jj_log_limit", new_limit)

  -- Note: No need to update keymaps since they are already set up and buffer-local

  -- Try to restore cursor position to the same commit
  vim.schedule(function()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    for i, line in ipairs(lines) do
      if line == current_line then
        vim.api.nvim_win_set_cursor(0, { i, cursor_pos[2] })
        return
      end
    end
    -- If exact line not found, try to restore by line number (might be off due to new commits)
    local max_line = #lines
    local safe_line = math.min(cursor_pos[1], max_line)
    vim.api.nvim_win_set_cursor(0, { safe_line, cursor_pos[2] })
  end)
end

-- Setup log buffer keymaps
local function setup_log_keymaps(bufnr, commit_data)
  local ui = require("jj-fugitive.ui")

  -- Show commit details
  ui.map(bufnr, "n", "<CR>", function()
    local line = vim.api.nvim_get_current_line()
    local commit_id = get_commit_from_line(line, commit_data)
    show_commit_details(commit_id, { update_current = true })
  end)

  ui.map(bufnr, "n", "o", function()
    local line = vim.api.nvim_get_current_line()
    local commit_id = get_commit_from_line(line, commit_data)
    show_commit_details(commit_id, { update_current = true })
  end)

  -- Edit at commit
  ui.map(bufnr, "n", "e", function()
    local line = vim.api.nvim_get_current_line()
    local commit_id = get_commit_from_line(line, commit_data)
    edit_at_commit(commit_id)
  end)

  -- New commit after this one
  ui.map(bufnr, "n", "n", function()
    local line = vim.api.nvim_get_current_line()
    local commit_id = get_commit_from_line(line, commit_data)
    new_after_commit(commit_id)
  end)

  -- Rebase onto commit
  ui.map(bufnr, "n", "r", function()
    local line = vim.api.nvim_get_current_line()
    local commit_id = get_commit_from_line(line, commit_data)
    rebase_onto_commit(commit_id)
  end)

  -- Abandon commit
  ui.map(bufnr, "n", "A", function()
    local line = vim.api.nvim_get_current_line()
    local commit_id = get_commit_from_line(line, commit_data)
    if commit_id then
      -- Ask for confirmation since this is destructive
      local choice = vim.fn.confirm(
        string.format(
          "Abandon commit %s? This will rebase its descendants onto its parent.",
          commit_id
        ),
        "&Yes\n&No",
        2
      )
      if choice == 1 then
        local main_module = require("jj-fugitive.init")
        local result = main_module.run_jj_command_from_module({ "abandon", commit_id })
        if result then
          vim.api.nvim_echo({ { "Abandoned commit: " .. commit_id, "MoreMsg" } }, false, {})
          M.show_log({ update_current = true })
        end
      end
    else
      vim.api.nvim_echo({ { "No commit selected", "WarningMsg" } }, false, {})
    end
  end)

  -- Squash commit into its parent
  ui.map(bufnr, "n", "s", function()
    local line = vim.api.nvim_get_current_line()
    local commit_id = get_commit_from_line(line, commit_data)
    if commit_id then
      -- Ask for confirmation since this will modify the commit
      local choice = vim.fn.confirm(
        string.format(
          "Squash commit %s into its parent? This will move its changes to the parent.",
          commit_id
        ),
        "&Yes\n&No",
        2
      )
      if choice == 1 then
        local main_module = require("jj-fugitive.init")
        local result = main_module.run_jj_command_from_module({ "squash", "-r", commit_id })
        if result then
          vim.api.nvim_echo({ { "Squashed commit: " .. commit_id, "MoreMsg" } }, false, {})
          M.show_log({ update_current = true })
        end
      end
    else
      vim.api.nvim_echo({ { "No commit selected", "WarningMsg" } }, false, {})
    end
  end)

  -- Split commit into two
  ui.map(bufnr, "n", "S", function()
    local line = vim.api.nvim_get_current_line()
    local commit_id = get_commit_from_line(line, commit_data)
    if commit_id then
      -- Ask for confirmation since this will modify the commit
      local choice = vim.fn.confirm(
        string.format(
          "Split commit %s into two? This will open an interactive editor to select changes.",
          commit_id
        ),
        "&Yes\n&No",
        2
      )
      if choice == 1 then
        local main_module = require("jj-fugitive.init")
        local result = main_module.run_jj_command_from_module({ "split", "-r", commit_id })
        if result then
          vim.api.nvim_echo({ { "Split commit: " .. commit_id, "MoreMsg" } }, false, {})
          M.show_log({ update_current = true })
        end
      end
    else
      vim.api.nvim_echo({ { "No commit selected", "WarningMsg" } }, false, {})
    end
  end)

  -- Duplicate commit (like "yank")
  ui.map(bufnr, "n", "y", function()
    local line = vim.api.nvim_get_current_line()
    local commit_id = get_commit_from_line(line, commit_data)
    if commit_id then
      -- Ask for confirmation since this will create a new commit
      local choice = vim.fn.confirm(
        string.format(
          "Duplicate commit %s? This will create a copy with the same content.",
          commit_id
        ),
        "&Yes\n&No",
        2
      )
      if choice == 1 then
        local main_module = require("jj-fugitive.init")
        local result = main_module.run_jj_command_from_module({ "duplicate", commit_id })
        if result then
          vim.api.nvim_echo({ { "Duplicated commit: " .. commit_id, "MoreMsg" } }, false, {})
          M.show_log({ update_current = true })
        end
      end
    else
      vim.api.nvim_echo({ { "No commit selected", "WarningMsg" } }, false, {})
    end
  end)

  -- Show unified diff for commit
  ui.map(bufnr, "n", "d", function()
    local line = vim.api.nvim_get_current_line()
    local commit_id = get_commit_from_line(line, commit_data)
    show_commit_diff(commit_id, { update_current = true })
  end)

  -- Show side-by-side diff for commit
  ui.map(bufnr, "n", "D", function()
    local line = vim.api.nvim_get_current_line()
    local commit_id = get_commit_from_line(line, commit_data)
    show_commit_diff(commit_id, { update_current = true, sidebyside = true })
  end)

  -- Toggle between diff and commit details
  ui.map(bufnr, "n", "<Tab>", function()
    local line = vim.api.nvim_get_current_line()
    local commit_id = get_commit_from_line(line, commit_data)
    -- Check current buffer to decide what to toggle to
    local current_bufname = vim.api.nvim_buf_get_name(0)
    if current_bufname:match("jj%-diff:") then
      -- Currently showing diff, switch to details
      show_commit_details(commit_id, { update_current = true })
    else
      -- Currently showing log or details, switch to diff
      show_commit_diff(commit_id, { update_current = true })
    end
  end)

  -- Close log view
  ui.map(bufnr, "n", "q", function()
    vim.cmd("close")
  end)

  -- Refresh log
  ui.map(bufnr, "n", "R", function()
    M.show_log()
  end)

  -- Expand log view (show more commits using -r .. with increased limit)
  ui.map(bufnr, "n", "=", function()
    expand_log_view(bufnr)
  end)

  ui.map(bufnr, "n", "+", function()
    expand_log_view(bufnr)
  end)

  -- Navigate to parent revision (vim-fugitive P)
  ui.map(bufnr, "n", "P", function()
    local line = vim.api.nvim_get_current_line()
    local commit_id = get_commit_from_line(line, commit_data)
    if commit_id then
      local main_module = require("jj-fugitive.init")
      local parent_result = main_module.run_jj_command_from_module({
        "log",
        "-r",
        commit_id .. "-",
        "--limit",
        "1",
        "--no-graph",
      })
      if parent_result then
        local parent_id = parent_result:match("([a-f0-9]+)$")
        if parent_id then
          -- Find and move cursor to parent commit line
          local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
          for i, buf_line in ipairs(lines) do
            if buf_line:find(parent_id, 1, true) then
              vim.api.nvim_win_set_cursor(0, { i, 0 })
              vim.api.nvim_echo({ { "Moved to parent: " .. parent_id, "MoreMsg" } }, false, {})
              return
            end
          end
          vim.api.nvim_echo(
            { { "Parent commit not visible in current log view", "WarningMsg" } },
            false,
            {}
          )
        end
      end
    end
  end)

  -- Navigate to next (child) revision (vim-fugitive N)
  ui.map(bufnr, "n", "N", function()
    local line = vim.api.nvim_get_current_line()
    local commit_id = get_commit_from_line(line, commit_data)
    if commit_id then
      local main_module = require("jj-fugitive.init")
      local child_result = main_module.run_jj_command_from_module({
        "log",
        "-r",
        commit_id .. "+",
        "--limit",
        "1",
        "--no-graph",
      })
      if child_result then
        local child_id = child_result:match("([a-f0-9]+)$")
        if child_id then
          -- Find and move cursor to child commit line
          local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
          for i, buf_line in ipairs(lines) do
            if buf_line:find(child_id, 1, true) then
              vim.api.nvim_win_set_cursor(0, { i, 0 })
              vim.api.nvim_echo({ { "Moved to child: " .. child_id, "MoreMsg" } }, false, {})
              return
            end
          end
          vim.api.nvim_echo(
            { { "Child commit not visible in current log view", "WarningMsg" } },
            false,
            {}
          )
        end
      end
    end
  end)

  -- Show help (vim-fugitive standard)
  ui.map(bufnr, "n", "g?", function()
    local help_lines = {
      "# jj-fugitive Log View Help",
      "",
      "Navigation:",
      "  j/k       - Move up/down through commits",
      "  gg/G      - Go to first/last commit",
      "  P         - Navigate to parent revision (vim-fugitive)",
      "  N         - Navigate to next/child revision (vim-fugitive)",
      "",
      "Commit Actions:",
      "  Enter/o   - Show commit details and changes",
      "  d         - Show unified diff for this commit",
      "  D         - Show side-by-side diff for this commit",
      "  Tab       - Toggle between diff and commit details",
      "  e         - Edit at this commit (jj edit)",
      "  n         - Create new commit after this one (jj new)",
      "  r         - Rebase current commit onto this one (jj rebase)",
      "  A         - Abandon commit (jj abandon)",
      "  s         - Squash commit into its parent (jj squash)",
      "  S         - Split commit into two (jj split)",
      "  y         - Duplicate commit (jj duplicate)",
      "",
      "View Actions:",
      "  =, +      - Expand log view (show more commits with --limit)",
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

    require("jj-fugitive.ui").show_help_popup(
      "jj-fugitive Log Help",
      help_lines,
      { width = 70, mark_plugin = true }
    )
  end)
end

-- Main function to show log view
function M.show_log(options)
  options = options or {}
  -- No default limit - use standard jj log behavior

  -- Only set revisions if explicitly provided
  -- Default jj log behavior shows recent commits without needing -r ..

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
  local limit_text = options.limit and string.format(" (limit: %d)", options.limit) or ""
  local header_lines = {
    "",
    "# jj Log View" .. limit_text,
    "# Navigate: j/k, P/N=parent/next, Enter=details, d=diff, D=side-by-side, Tab=toggle, e=edit, +=expand, q=quit, g?=help",
    "",
  }

  local bufname = "jj-log"
  local bufnr

  -- If update_current is true, update the current buffer instead of creating new one
  if options.update_current then
    bufnr = vim.api.nvim_get_current_buf()

    -- Only update if we're in a jj-related buffer
    if require("jj-fugitive.ui").is_jj_buffer(bufnr) then
      -- Update buffer content
      ansi.update_colored_buffer(bufnr, log_output, header_lines, {
        prefix = "JjLog",
        custom_syntax = {
          ["^# jj Log View$"] = "JjLogHeader",
          ["^# Navigate:.*$"] = "JjLogSubHeader",
        },
      })

      -- Update buffer name
      vim.api.nvim_buf_set_name(bufnr, bufname)

      -- Clear old buffer variables
      pcall(vim.api.nvim_buf_del_var, bufnr, "jj_previous_view")
    else
      -- Fallback to creating new buffer if not in jj buffer
      options.update_current = false
    end
  end

  if not options.update_current then
    -- Create buffer with native jj log output and ANSI color processing
    bufnr = ansi.create_colored_buffer(log_output, bufname, header_lines, {
      prefix = "JjLog",
      custom_syntax = {
        ["^# jj Log View$"] = "JjLogHeader",
        ["^# Navigate:.*$"] = "JjLogSubHeader",
      },
    })
  end

  -- Apply custom header highlighting after buffer creation
  vim.api.nvim_buf_call(bufnr, function()
    vim.cmd("highlight default JjLogHeader ctermfg=14 guifg=Cyan cterm=bold gui=bold")
    vim.cmd("highlight default JjLogSubHeader ctermfg=8 guifg=Gray cterm=italic gui=italic")
  end)

  -- Store current limit in buffer variable for expand functionality
  vim.api.nvim_buf_set_var(bufnr, "jj_log_limit", options.limit or 0)

  -- Setup keymaps for interaction (once per buffer)
  local ui = require("jj-fugitive.ui")
  if ui.set_once(bufnr, "log_keymaps") then
    setup_log_keymaps(bufnr, commit_data)
  end

  if not options.update_current then
    -- Open in current window or split
    require("jj-fugitive.ui").ensure_buffer_visible(bufnr)
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
  require("jj-fugitive.ui").set_statusline(bufnr, "jj-log: Repository History")
end

-- Export show_commit_details for use by other modules
M.show_commit_details = show_commit_details
M.show_commit_diff = show_commit_diff

return M
