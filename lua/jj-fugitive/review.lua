local M = {}

local BUF_PATTERN = "jj%-review"
local BUF_NAME = "jj-review"

local function setup_keymaps(bufnr)
  local ui = require("jj-fugitive.ui")
  if ui.buf_var(bufnr, "jj_review_keymaps_set", false) then
    return
  end
  pcall(vim.api.nvim_buf_set_var, bufnr, "jj_review_keymaps_set", true)

  ui.map(bufnr, "n", "q", function()
    vim.cmd(ui.close_cmd())
  end)

  ui.map(bufnr, "n", "gl", function()
    vim.cmd(ui.close_cmd())
    require("jj-fugitive.log").show()
  end)

  ui.map(bufnr, "n", "gs", function()
    vim.cmd(ui.close_cmd())
    require("jj-fugitive.status").show()
  end)

  ui.map(bufnr, "n", "g?", function()
    ui.help_popup("jj-fugitive Review", {
      "Review buffer",
      "",
      "Views:",
      "  gl      Switch to log view",
      "  gs      Switch to status view",
      "",
      "Other:",
      "  q       Close",
      "  g?      This help",
    })
  end)
end

local function get_buffer()
  local ui = require("jj-fugitive.ui")
  local existing = ui.find_buf(BUF_PATTERN)
  if existing then
    setup_keymaps(existing)
    return existing
  end

  local init = require("jj-fugitive")
  local repo_root = init.repo_root() or vim.fn.getcwd()
  local bufnr = ui.create_scratch_buffer({
    name = BUF_NAME,
    filetype = "markdown",
    modifiable = true,
    bufhidden = "hide",
  })

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "# AI Review Packet",
    "",
    "You are reviewing a jj repository diff.",
    "Treat each review item as a separate code review concern.",
    "Prioritize correctness bugs, regressions, missing edge cases, risky behavior changes, and unclear intent.",
    "Be concrete and skeptical. Do not assume the code is correct.",
    "For each item, explain the risk, why it matters, and what change you recommend.",
    "Respond item-by-item and reference the review item number in your answer.",
    "",
    "## Repository Context",
    "- Repo type: jj",
    "- Repository root: " .. repo_root,
    "- Source: jj-fugitive unified diff review",
    "",
    "## Review Items",
    "",
  })
  vim.bo[bufnr].modified = false
  setup_keymaps(bufnr)

  return bufnr
end

local function next_comment_number(bufnr)
  local count = 0
  for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    if line:match("^### Review Item %d+$") then
      count = count + 1
    end
  end
  return count + 1
end

local function trim_inline_prefix(line)
  return (line or ""):gsub("^    ", "")
end

local function find_file_for_cursor(lines, cursor_line)
  for i = cursor_line, 1, -1 do
    local file = lines[i]:match("^diff %-%-git a/(.-) b/")
    if file then
      return file
    end
  end
  return nil
end

local function find_hunk_for_cursor(lines, cursor_line, start_line, normalize)
  for i = cursor_line, start_line, -1 do
    local line = normalize(lines[i])
    if line:match("^@@") then
      return line
    end
  end
  return nil
end

local function unified_diff_entry(bufnr, ctx)
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local change_line = lines[cursor_line] or ""
  local file = ctx.file or find_file_for_cursor(lines, cursor_line)
  if not file then
    return nil, "Place the cursor on a diff line"
  end

  return {
    file = file,
    rev = ctx.rev or "@",
    hunk = find_hunk_for_cursor(lines, cursor_line, 1, function(line)
      return line
    end),
    change = change_line,
  }
end

local function status_inline_entry(bufnr)
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local state = require("jj-fugitive.ui").buf_var(bufnr, "jj_status_inline_diffs", {})
  local active
  for _, item in ipairs(state) do
    if cursor_line >= item.start_line and cursor_line <= item.end_line then
      active = item
      break
    end
  end

  if not active then
    return nil, "Place the cursor on an inline diff line"
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local change_line = trim_inline_prefix(lines[cursor_line] or "")
  return {
    file = active.file,
    rev = active.rev or "@",
    hunk = find_hunk_for_cursor(lines, cursor_line, active.start_line, trim_inline_prefix),
    change = change_line,
  }
end

local function format_entry(entry, number)
  local lines = {
    "### Review Item " .. number,
    "- File: " .. entry.file,
    "- Revision: " .. entry.rev,
  }

  if entry.hunk and entry.hunk ~= "" then
    table.insert(lines, "- Hunk: " .. entry.hunk)
  end

  table.insert(lines, "- Selected line:")
  table.insert(lines, "```diff")
  table.insert(lines, entry.change ~= "" and entry.change or "(blank line)")
  table.insert(lines, "```")
  table.insert(lines, "- Reviewer comment:")

  for _, line in ipairs(vim.split(entry.comment, "\n")) do
    table.insert(lines, "  " .. line)
  end

  table.insert(lines, "")
  return lines
end

function M.show()
  local ui = require("jj-fugitive.ui")
  local bufnr = get_buffer()
  ui.ensure_visible(bufnr)
  ui.set_statusline(bufnr, "jj-review")
  return bufnr
end

function M.append(entry)
  local bufnr = get_buffer()
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local number = next_comment_number(bufnr)
  local lines = format_entry(entry, number)

  vim.api.nvim_buf_set_lines(bufnr, line_count, line_count, false, lines)
  vim.bo[bufnr].modified = false

  require("jj-fugitive.ui").info("Review added (" .. number .. ")")
end

function M.comment_current_line(bufnr)
  local ui = require("jj-fugitive.ui")
  local ctx = ui.buf_var(bufnr, "jj_review_context", nil)
  if not ctx then
    ui.warn("Review comments are not available in this buffer")
    return
  end

  local entry, err
  if ctx.kind == "status_inline" then
    entry, err = status_inline_entry(bufnr)
  else
    entry, err = unified_diff_entry(bufnr, ctx)
  end

  if not entry then
    ui.warn(err)
    return
  end

  vim.ui.input({ prompt = "Review comment: " }, function(comment)
    if not comment or comment:match("^%s*$") then
      return
    end
    entry.comment = comment
    M.append(entry)
  end)
end

return M
