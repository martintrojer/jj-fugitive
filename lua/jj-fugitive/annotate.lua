local M = {}

local core_annotate = require("fugitive-core.views.annotate")

-- History stack for blame drill-down (~ to go deeper, <BS> to go back)
local history_stack = {}

function M.show(filename, rev, _keep_stack)
  if not _keep_stack then
    history_stack = {}
  end
  local init = require("jj-fugitive")
  local ui = require("jj-fugitive.ui")

  filename = core_annotate.resolve_filename(filename, init.repo_root())
  if not filename then
    ui.err("No file to annotate")
    return false
  end

  local annotate_args = { "file", "annotate", filename }
  if rev then
    table.insert(annotate_args, "-r")
    table.insert(annotate_args, rev)
  end
  local output = init.run_jj(annotate_args)
  if not output then
    return false
  end

  local annotations = {}
  for line in output:gmatch("[^\n]+") do
    local prefix = line:match("^(.-)%s+%d+:")
    table.insert(annotations, prefix or line)
  end

  local source_lines
  if rev then
    local file_content = ui.file_at_rev(filename, rev)
    source_lines = vim.split(file_content, "\n")
  else
    local buf_name = vim.api.nvim_buf_get_name(0)
    if buf_name ~= "" and vim.bo.buftype == "" then
      local ok, lines = pcall(vim.fn.readfile, buf_name)
      source_lines = ok and lines or {}
    else
      source_lines = {}
    end
  end

  local rev_suffix = rev and (" @ " .. rev) or ""

  local ann_buf, src_buf, close = core_annotate.open_split({
    ann_name = "jj-annotate: " .. filename .. rev_suffix,
    src_name = filename .. rev_suffix,
    annotations = annotations,
    source_lines = source_lines,
    filename = filename,
    ann_syntax = function(bufnr)
      vim.api.nvim_buf_call(bufnr, function()
        vim.cmd("syntax match JjAnnotateChangeId '^\\S\\+'")
        vim.cmd("syntax match JjAnnotateAuthor '\\s\\S\\+\\s\\d'")
        vim.cmd("highlight default link JjAnnotateChangeId Identifier")
        vim.cmd("highlight default link JjAnnotateAuthor Comment")
      end)
    end,
    statusline_ann = "jj-annotate: " .. filename .. rev_suffix,
    statusline_src = filename .. rev_suffix,
  })

  if rev then
    pcall(vim.api.nvim_buf_set_var, src_buf, "jj_annotate_source", true)
  end

  ui.map(ann_buf, "n", "<CR>", function()
    local ann_line = vim.api.nvim_get_current_line()
    local change_id = ann_line:match("^(%S+)")
    if not change_id or #change_id < 8 then
      return
    end

    local ansi = require("fugitive-core.ansi")
    local result = init.run_jj({ "show", "--color", "always", "--git", change_id })
    if not result then
      return
    end
    local header = { "", "# Commit: " .. change_id, "# Press g? for help, q to close", "" }
    local show_buf = ansi.create_colored_buffer(result, "jj-show: " .. change_id, header, {
      prefix = "JjShow",
    })

    ui.open_pane({ split_cmd = "botright split" })
    vim.api.nvim_set_current_buf(show_buf)
    require("jj-fugitive.log").setup_detail_keymaps(show_buf, "Show", change_id)
    ui.set_statusline(show_buf, "jj-show: " .. change_id)
  end)

  local function close_and_cleanup()
    close()
    if ui.buf_var(src_buf, "jj_annotate_source", false) and vim.api.nvim_buf_is_valid(src_buf) then
      pcall(vim.api.nvim_buf_delete, src_buf, { force = true })
    end
  end

  -- Drill into parent revision
  ui.map(ann_buf, "n", "~", function()
    local ann_line = vim.api.nvim_get_current_line()
    local change_id = ann_line:match("^(%S+)")
    if not change_id or #change_id < 8 then
      return
    end
    table.insert(history_stack, rev)
    close_and_cleanup()
    local ok = M.show(filename, change_id .. "-", true)
    if not ok then
      table.remove(history_stack)
      M.show(filename, rev, true)
    end
  end)

  -- Go back to child revision
  ui.map(ann_buf, "n", "<BS>", function()
    if #history_stack == 0 then
      return
    end
    local prev_rev = table.remove(history_stack)
    close_and_cleanup()
    M.show(filename, prev_rev, true)
  end)

  ui.setup_view_keymaps(ann_buf, {
    close = function()
      history_stack = {}
      close_and_cleanup()
    end,
    log = function()
      history_stack = {}
      close()
      require("jj-fugitive.log").show()
    end,
    status = function()
      history_stack = {}
      close()
      require("jj-fugitive.status").show()
    end,
    bookmark = function()
      history_stack = {}
      close()
      require("jj-fugitive.bookmark").show()
    end,
    help = function()
      ui.help_popup("jj-fugitive Annotate", {
        "Annotate view for " .. filename .. rev_suffix,
        "",
        "Actions:",
        "  <CR>    Show commit for this line",
        "  ~       Re-annotate at parent of this line's change",
        "  <BS>    Go back to previous revision",
        "",
        "Views:",
        "  gb      Switch to bookmark view",
        "  gl      Switch to log view",
        "  gs      Switch to status view",
        "",
        "Other:",
        "  q       Close annotation",
        "  g?      This help",
      })
    end,
  })

  if rev then
    local depth = #history_stack
    local depth_info = depth > 0 and (" [depth " .. depth .. ", <BS> to go back]") or ""
    ui.info("Annotate: " .. filename .. " @ " .. rev .. depth_info)
  end

  return true
end

return M
