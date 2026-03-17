local M = {}

local ansi = require("jj-fugitive.ansi")

--- Get diff output from jj with ANSI colors.
--- file: optional filename to restrict diff
--- rev: optional revision (defaults to working copy)
local function get_diff(file, rev)
  local init = require("jj-fugitive.init")
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

--- Setup keymaps for a unified diff buffer.
local function setup_diff_keymaps(bufnr, filename)
  local ui = require("jj-fugitive.ui")

  ui.map(bufnr, "n", "q", "<cmd>close<CR>")

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
      "Navigation:",
      "  [c      Previous change",
      "  ]c      Next change",
      "",
      "Actions:",
      "  o       Open file in editor",
      "  D       Side-by-side diff",
      "  q       Close",
      "  g?      This help",
    })
  end)
end

--- Show unified diff view.
--- file_or_args: filename string, or nil for all changes
function M.show(file_or_args)
  local filename = nil
  if file_or_args and file_or_args ~= "" then
    filename = vim.fn.expand(file_or_args:match("^%s*(.-)%s*$"))
  else
    -- If in a file buffer, diff that file
    local buf_name = vim.api.nvim_buf_get_name(0)
    if buf_name ~= "" then
      local cwd = vim.fn.getcwd()
      if buf_name:find(cwd, 1, true) == 1 then
        filename = buf_name:sub(#cwd + 2)
      else
        filename = buf_name
      end
    end
  end

  local output = get_diff(filename)
  if not output then
    return
  end

  if output:match("^%s*$") then
    vim.api.nvim_echo(
      { { "No changes in " .. (filename or "working copy"), "WarningMsg" } },
      false,
      {}
    )
    return
  end

  local file_desc = filename or "all changes"
  local header = {
    "",
    "# Diff: " .. file_desc,
    "# Press g? for help, q to close",
    "",
  }

  local bufname = "jj-diff: " .. file_desc
  local bufnr = ansi.create_colored_buffer(output, bufname, header, { prefix = "JjDiff" })

  vim.cmd("split")
  vim.api.nvim_set_current_buf(bufnr)

  setup_diff_keymaps(bufnr, filename)

  local ui = require("jj-fugitive.ui")
  ui.set_statusline(bufnr, "jj-diff: " .. file_desc)
end

--- Show side-by-side diff using Neovim's built-in diffthis.
function M.show_sidebyside(filename)
  if not filename then
    require("jj-fugitive.ui").err("Side-by-side diff requires a filename")
    return
  end

  local init = require("jj-fugitive.init")
  local ui = require("jj-fugitive.ui")

  -- Use jj to get both sides — reliable regardless of cwd
  local original = init.run_jj({ "file", "show", filename, "-r", "@-" }) or ""
  local current = init.run_jj({ "file", "show", filename, "-r", "@" }) or ""

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
      vim.cmd("tabclose")
      vim.cmd("edit " .. vim.fn.fnameescape(filename))
    end)
  end
end

return M
