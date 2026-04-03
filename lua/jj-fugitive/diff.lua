local M = {}

local ansi = require("jj-fugitive.ansi")

--- Get diff output from jj with ANSI colors.
--- file: optional filename to restrict diff
--- rev: optional revision (defaults to working copy)
local function get_diff(file, rev)
  local init = require("jj-fugitive")
  local args = { "diff", "--color", "always", "--git" }

  if rev then
    table.insert(args, "-r")
    table.insert(args, rev)
  end

  if file then
    table.insert(args, file)
  end

  return init.run_jj(args)
end

local function set_review_context(bufnr, ctx)
  pcall(vim.api.nvim_buf_set_var, bufnr, "jj_review_context", ctx)
end

--- Setup keymaps for a unified diff buffer.
local function setup_diff_keymaps(bufnr, filename)
  local ui = require("jj-fugitive.ui")
  if ui.buf_var(bufnr, "jj_diff_keymaps_set", false) then
    return
  end
  pcall(vim.api.nvim_buf_set_var, bufnr, "jj_diff_keymaps_set", true)

  ui.map(bufnr, "n", "q", function()
    vim.cmd(ui.close_cmd())
  end)

  ui.map(bufnr, "n", "cR", function()
    require("jj-fugitive.review").comment_current_line(bufnr)
  end)

  ui.map(bufnr, "n", "gR", function()
    require("jj-fugitive.review").show()
  end)

  ui.map(bufnr, "n", "gb", function()
    vim.cmd(ui.close_cmd())
    require("jj-fugitive.bookmark").show()
  end)

  ui.map(bufnr, "n", "gl", function()
    vim.cmd(ui.close_cmd())
    require("jj-fugitive.log").show()
  end)

  ui.map(bufnr, "n", "gs", function()
    vim.cmd(ui.close_cmd())
    require("jj-fugitive.status").show()
  end)

  if filename then
    ui.map(bufnr, "n", "o", function()
      vim.cmd("edit " .. vim.fn.fnameescape(filename))
    end)

    ui.map(bufnr, "n", "D", function()
      M.show_sidebyside(filename)
    end)
  end

  ui.map(bufnr, "n", "g?", function()
    ui.help_popup("jj-fugitive Diff", {
      "Diff view",
      "",
      "Navigation:",
      "  [c      Previous change",
      "  ]c      Next change",
      "",
      "Actions:",
      "  cR      Add review comment",
      "  gR      Open review buffer",
      "  o       Open file in editor",
      "  D       Side-by-side diff",
      "",
      "Views:",
      "  gb      Switch to bookmark view",
      "  gl      Switch to log view",
      "  gs      Switch to status view",
      "",
      "Other:",
      "  q       Close",
      "  g?      This help",
    })
  end)
end

--- Show unified diff view.
--- opts: filename string, or { file = "...", rev = "..." }, or nil for all changes
function M.show(opts)
  if type(opts) ~= "table" then
    opts = { file = opts }
  end

  local filename = nil
  local rev = opts.rev

  if opts.file and opts.file ~= "" then
    filename = vim.fn.expand(opts.file:match("^%s*(.-)%s*$"))
  else
    -- If in a real file buffer, diff that file
    local buf_name = vim.api.nvim_buf_get_name(0)
    if buf_name ~= "" and vim.bo.buftype == "" then
      local cwd = vim.fn.getcwd()
      if buf_name:find(cwd, 1, true) == 1 then
        filename = buf_name:sub(#cwd + 2)
      else
        filename = buf_name
      end
    end
  end

  local output = get_diff(filename, rev)
  if not output then
    return
  end

  if output:match("^%s*$") then
    require("jj-fugitive.ui").warn("No changes in " .. (filename or rev or "working copy"))
    return
  end

  local file_desc = filename or rev or "all changes"
  local header = {
    "",
    "# Diff: " .. file_desc,
    "# Press g? for help, q to close",
    "",
  }

  local ui = require("jj-fugitive.ui")
  local bufname = "jj-diff: " .. file_desc
  local existing = ui.find_buf(vim.pesc(bufname))
  local bufnr

  if existing then
    bufnr = existing
    ansi.update_colored_buffer(bufnr, output, header, { prefix = "JjDiff" })
  else
    bufnr = ansi.create_colored_buffer(output, bufname, header, { prefix = "JjDiff" })
  end

  set_review_context(bufnr, {
    kind = "unified_diff",
    file = filename,
    rev = rev or "@",
  })
  setup_diff_keymaps(bufnr, filename)

  ui.ensure_visible(bufnr)

  ui.set_statusline(bufnr, "jj-diff: " .. file_desc)
end

--- Show side-by-side diff using Neovim's built-in diffthis.
function M.show_sidebyside(filename)
  if not filename then
    require("jj-fugitive.ui").err("Side-by-side diff requires a filename")
    return
  end

  local ui = require("jj-fugitive.ui")

  local original = ui.file_at_rev(filename, "@-")
  local current = ui.file_at_rev(filename, "@")

  -- Create side-by-side layout in a new tab
  local left, right = ui.open_sidebyside(
    original,
    filename .. " (parent @-)",
    current,
    filename .. " (working copy @)",
    filename
  )

  -- Additional keymaps for working copy diff
  for _, buf in ipairs({ left, right }) do
    ui.map(buf, "n", "o", function()
      vim.cmd(ui.close_cmd())
      vim.cmd("edit " .. vim.fn.fnameescape(filename))
    end)
  end
end

return M
