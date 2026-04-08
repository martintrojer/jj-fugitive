local M = {}

local core_diff = require("fugitive-core.views.diff")

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

local function setup_diff_keymaps(bufnr, filename, review_ctx)
  local ui = require("jj-fugitive.ui")
  if ui.buf_var(bufnr, "jj_diff_keymaps_set", false) then
    return
  end
  pcall(vim.api.nvim_buf_set_var, bufnr, "jj_diff_keymaps_set", true)

  ui.map(bufnr, "n", "q", function()
    vim.cmd(ui.close_cmd())
  end)

  local init = require("jj-fugitive")
  if init.review_config then
    ui.map(bufnr, "n", "cR", function()
      require("redline").comment_unified_diff(init.review_config, bufnr, review_ctx)
    end)
    ui.map(bufnr, "n", "gR", function()
      require("redline").show(init.review_config)
    end)
  end

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

function M.show(opts)
  if type(opts) ~= "table" then
    opts = { file = opts }
  end

  local filename = nil
  local rev = opts.rev

  if opts.file and opts.file ~= "" then
    filename = vim.fn.expand(opts.file:match("^%s*(.-)%s*$"))
  else
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

  local file_desc = filename or rev or "all changes"
  local bufname = "jj-diff: " .. file_desc
  local review_ctx = { file = filename, rev = rev or "@" }

  core_diff.show({
    get_diff = function()
      return get_diff(filename, rev)
    end,
    on_empty = function()
      require("jj-fugitive.ui").warn("No changes in " .. file_desc)
    end,
    buf_name = bufname,
    buf_pattern = vim.pesc(bufname),
    ansi_prefix = "JjDiff",
    header = { "", "# Diff: " .. file_desc, "# Press g? for help, q to close", "" },
    statusline = "jj-diff: " .. file_desc,
    setup = function(bufnr)
      setup_diff_keymaps(bufnr, filename, review_ctx)
    end,
  })
end

function M.show_sidebyside(filename)
  if not filename then
    require("jj-fugitive.ui").err("Side-by-side diff requires a filename")
    return
  end

  local ui = require("jj-fugitive.ui")

  local original = ui.file_at_rev(filename, "@-")
  local current = ui.file_at_rev(filename, "@")

  local left, right = ui.open_sidebyside(
    original,
    filename .. " (parent @-)",
    current,
    filename .. " (working copy @)",
    filename
  )

  for _, buf in ipairs({ left, right }) do
    ui.map(buf, "n", "o", function()
      vim.cmd(ui.close_cmd())
      vim.cmd("edit " .. vim.fn.fnameescape(filename))
    end)
  end
end

return M
