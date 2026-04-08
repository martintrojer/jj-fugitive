local M = {}

local core_list = require("fugitive-core.views.list")

local BUF_PATTERN = "jj%-bookmarks"
local BUF_NAME = "jj-bookmarks"

local function get_bookmarks()
  return require("jj-fugitive").run_jj({ "bookmark", "list", "--all" })
end

local function bookmark_from_line(line)
  if not line or line == "" or line:match("^%s*#") then
    return nil
  end
  local name = line:match("^(%S+):")
  if not name then
    return nil
  end
  name = name:gsub("%s*%(.-%)%s*", "")
  return name
end

local function run_and_refresh(args, msg)
  local init = require("jj-fugitive")
  local result = init.run_jj(args)
  if result then
    if msg then
      require("jj-fugitive.ui").info(msg)
    end
    init.refresh_views()
  end
end

local function setup_keymaps(bufnr)
  local ui = require("jj-fugitive.ui")
  if ui.buf_var(bufnr, "jj_bookmark_keymaps_set", false) then
    return
  end
  pcall(vim.api.nvim_buf_set_var, bufnr, "jj_bookmark_keymaps_set", true)

  ui.map(bufnr, "n", "c", function()
    vim.ui.input({ prompt = "New bookmark name: " }, function(name)
      if name and name ~= "" then
        vim.ui.input({ prompt = "At revision (default @): " }, function(rev)
          if not rev or rev == "" then
            rev = "@"
          end
          run_and_refresh({ "bookmark", "create", name, "-r", rev }, "Created bookmark: " .. name)
        end)
      end
    end)
  end)

  ui.map(bufnr, "n", "d", function()
    local name = bookmark_from_line(vim.api.nvim_get_current_line())
    if name and ui.confirm("Delete bookmark '" .. name .. "'?") then
      run_and_refresh({ "bookmark", "delete", name }, "Deleted bookmark: " .. name)
    end
  end)

  ui.map(bufnr, "n", "m", function()
    local name = bookmark_from_line(vim.api.nvim_get_current_line())
    if not name then
      return
    end
    vim.ui.input({ prompt = "Move '" .. name .. "' to revision: " }, function(rev)
      if rev and rev ~= "" then
        run_and_refresh(
          { "bookmark", "set", name, "-r", rev, "--allow-backwards" },
          "Moved " .. name .. " -> " .. rev
        )
      end
    end)
  end)

  ui.map(bufnr, "n", "t", function()
    local name = bookmark_from_line(vim.api.nvim_get_current_line())
    if name then
      run_and_refresh({ "bookmark", "track", name .. "@origin" }, "Tracking: " .. name)
    end
  end)

  ui.map(bufnr, "n", "u", function()
    local name = bookmark_from_line(vim.api.nvim_get_current_line())
    if name then
      run_and_refresh({ "bookmark", "untrack", name .. "@origin" }, "Untracked: " .. name)
    end
  end)

  ui.map(bufnr, "n", "p", function()
    local name = bookmark_from_line(vim.api.nvim_get_current_line())
    if name then
      run_and_refresh({ "git", "push", "--bookmark", name }, "Pushed: " .. name)
    end
  end)

  ui.map(bufnr, "n", "f", function()
    run_and_refresh({ "git", "fetch" }, "Fetched from remote")
  end)

  ui.map(bufnr, "n", "go", function()
    local name = bookmark_from_line(vim.api.nvim_get_current_line())
    if name then
      run_and_refresh({ "edit", name }, "Editing at " .. name)
    end
  end)

  ui.map(bufnr, "n", "R", function()
    M.refresh()
  end)

  ui.map(bufnr, "n", "gu", function()
    require("jj-fugitive").undo()
  end)

  ui.map(bufnr, "n", "gl", function()
    vim.cmd(ui.close_cmd())
    require("jj-fugitive.log").show()
  end)

  ui.map(bufnr, "n", "gs", function()
    vim.cmd(ui.close_cmd())
    require("jj-fugitive.status").show()
  end)

  ui.map(bufnr, "n", "ga", function()
    ui.show_aliases()
  end)

  local init = require("jj-fugitive")
  if init.review_config then
    ui.map(bufnr, "n", "gR", function()
      require("redline").show(init.review_config)
    end)
  end

  ui.map(bufnr, "n", "q", function()
    vim.cmd(ui.close_cmd())
  end)

  ui.map(bufnr, "n", "g?", function()
    ui.help_popup("jj-fugitive Bookmarks", {
      "Bookmarks view",
      "",
      "Actions:",
      "  c       Create bookmark",
      "  d       Delete bookmark under cursor",
      "  go      Edit at bookmark's revision",
      "  m       Move bookmark to prompted revision",
      "",
      "Remote:",
      "  t       Track remote bookmark (origin)",
      "  u       Untrack remote bookmark",
      "  p       Push bookmark to remote",
      "  f       Fetch from remote",
      "",
      "Views:",
      "  gl      Switch to log view",
      "  gs      Switch to status view",
      "  gR      Open review buffer",
      "",
      "Other:",
      "  ga      Show jj aliases",
      "  gu      Undo last jj operation",
      "  R       Refresh",
      "  q       Close",
      "  g?      This help",
    })
  end)
end

local function format_lines(output)
  local lines = {
    "",
    "# jj Bookmarks",
    "# Press g? for help",
    "",
  }
  for _, line in ipairs(vim.split(output, "\n")) do
    if line ~= "" then
      table.insert(lines, line)
    end
  end
  return lines
end

function M.refresh()
  core_list.refresh({
    get_data = get_bookmarks,
    format_lines = format_lines,
    buf_pattern = BUF_PATTERN,
    on_refresh = function(bufnr)
      setup_keymaps(bufnr)
    end,
  })
end

function M.show()
  core_list.show({
    get_data = get_bookmarks,
    format_lines = format_lines,
    buf_pattern = BUF_PATTERN,
    buf_name = BUF_NAME,
    statusline = "jj-bookmarks",
    first_item = bookmark_from_line,
    setup = function(bufnr)
      vim.api.nvim_buf_call(bufnr, function()
        vim.cmd("syntax match JjBookmarkHeader '^#.*'")
        vim.cmd("syntax match JjBookmarkName '^[a-zA-Z][a-zA-Z0-9_/-]*:'")
        vim.cmd("highlight default link JjBookmarkHeader Comment")
        vim.cmd("highlight default link JjBookmarkName Identifier")
      end)
      setup_keymaps(bufnr)
    end,
  })
end

return M
