local M = {}

--- Show blame/annotate for the current file.
--- Opens a vertical split with annotations aligned to the source buffer.
--- rev: optional revision to annotate at (defaults to working copy)
function M.show(filename, rev)
  local init = require("jj-fugitive")
  local ui = require("jj-fugitive.ui")

  -- Use current buffer's file if none specified
  if not filename or filename == "" then
    local buf_name = vim.api.nvim_buf_get_name(0)
    if buf_name == "" or vim.bo.buftype ~= "" then
      ui.err("No file to annotate")
      return
    end
    local root = init.repo_root()
    if root and buf_name:find(root, 1, true) == 1 then
      filename = buf_name:sub(#root + 2)
    else
      filename = buf_name
    end
  end

  local annotate_args = { "file", "annotate", filename }
  if rev then
    table.insert(annotate_args, "-r")
    table.insert(annotate_args, rev)
  end
  local output = init.run_jj(annotate_args)
  if not output then
    return
  end

  -- Parse annotations: separate the annotation prefix from the file content
  local annotations = {}
  for line in output:gmatch("[^\n]+") do
    -- Format: "changeid author date    N: content"
    -- Strip the line number and content, keep the annotation prefix
    local prefix = line:match("^(.-)%s+%d+:")
    table.insert(annotations, prefix or line)
  end

  -- Create the annotation buffer
  local rev_suffix = rev and (" @ " .. rev) or ""
  local ann_buf = ui.create_scratch_buffer({
    name = "jj-annotate: " .. filename .. rev_suffix,
  })

  vim.api.nvim_buf_set_option(ann_buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(ann_buf, 0, -1, false, annotations)
  vim.api.nvim_buf_set_option(ann_buf, "modifiable", false)
  vim.api.nvim_buf_set_option(ann_buf, "modified", false)

  -- Highlighting
  vim.api.nvim_buf_call(ann_buf, function()
    vim.cmd("syntax match JjAnnotateChangeId '^\\S\\+'")
    vim.cmd("syntax match JjAnnotateAuthor '\\s\\S\\+\\s\\d'")
    vim.cmd("highlight default link JjAnnotateChangeId Identifier")
    vim.cmd("highlight default link JjAnnotateAuthor Comment")
  end)

  -- Open annotation as a left vsplit
  vim.cmd("vsplit")
  vim.cmd("wincmd H")
  vim.api.nvim_set_current_buf(ann_buf)

  -- Size the annotation window to fit content
  local max_width = 0
  for _, ann in ipairs(annotations) do
    if #ann > max_width then
      max_width = #ann
    end
  end
  vim.api.nvim_win_set_width(0, math.min(max_width + 1, 60))

  -- Lock scrolling between the two windows
  vim.cmd("setlocal scrollbind nowrap nonumber norelativenumber")
  vim.cmd("wincmd l")
  vim.cmd("setlocal scrollbind")
  vim.cmd("syncbind")
  vim.cmd("wincmd h")

  -- Keymaps
  ui.map(ann_buf, "n", "<CR>", function()
    local ann_line = vim.api.nvim_get_current_line()
    local change_id = ann_line:match("^(%S+)")
    if not change_id or #change_id < 8 then
      return
    end

    local ansi = require("jj-fugitive.ansi")
    local result = init.run_jj({ "show", "--color", "always", "--git", change_id })
    if not result then
      return
    end
    local header = { "", "# Commit: " .. change_id, "# Press g? for help, q to close", "" }
    local show_buf = ansi.create_colored_buffer(result, "jj-show: " .. change_id, header, {
      prefix = "JjShow",
    })

    -- botright split spans full width across annotate + source panes
    ui.open_pane({ split_cmd = "botright split" })
    vim.api.nvim_set_current_buf(show_buf)
    require("jj-fugitive.log").setup_detail_keymaps(show_buf, "Show", change_id)
    ui.set_statusline(show_buf, "jj-show: " .. change_id)
  end)

  local function close_annotate()
    vim.cmd("close")
    -- Restore the source window's scrollbind
    vim.cmd("setlocal noscrollbind")
  end

  -- Re-annotate at parent of change under cursor
  ui.map(ann_buf, "n", "p", function()
    local ann_line = vim.api.nvim_get_current_line()
    local change_id = ann_line:match("^(%S+)")
    if not change_id or #change_id < 8 then
      return
    end
    close_annotate()
    M.show(filename, change_id .. "-")
  end)

  ui.map(ann_buf, "n", "q", close_annotate)

  ui.map(ann_buf, "n", "g?", function()
    ui.help_popup("jj-fugitive Annotate", {
      "Annotate view for " .. filename .. rev_suffix,
      "",
      "Actions:",
      "  <CR>    Show commit for this line",
      "  p       Re-annotate at parent of this line's change",
      "",
      "Other:",
      "  q       Close annotation",
      "  g?      This help",
    })
  end)

  ui.set_statusline(ann_buf, "jj-annotate: " .. filename .. rev_suffix)
end

return M
