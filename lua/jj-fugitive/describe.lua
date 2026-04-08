local M = {}

local open_editor = require("fugitive-core.views.describe").open_editor

local function get_description(rev)
  local result =
    require("jj-fugitive").run_jj({ "log", "-r", rev, "--no-graph", "-T", "description" })
  return result and result:gsub("%s+$", "") or ""
end

local function setup_keymaps(bufnr, discard_and_close)
  local ui = require("jj-fugitive.ui")

  ui.map(bufnr, "n", "gl", function()
    discard_and_close()
    require("jj-fugitive.log").show()
  end)

  ui.map(bufnr, "n", "gs", function()
    discard_and_close()
    require("jj-fugitive.status").show()
  end)

  ui.map(bufnr, "n", "gb", function()
    discard_and_close()
    require("jj-fugitive.bookmark").show()
  end)

  ui.map(bufnr, "n", "g?", function()
    ui.help_popup("jj-fugitive Describe", {
      "Editing commit description",
      "",
      "Actions:",
      "  :w      Save description",
      "",
      "Views:",
      "  gb      Switch to bookmark view",
      "  gl      Switch to log view",
      "  gs      Switch to status view",
      "",
      "Other:",
      "  q       Abort (close without saving)",
      "  g?      This help",
    })
  end)
end

function M.describe(rev)
  rev = rev or "@"
  local init = require("jj-fugitive")

  local description = get_description(rev)

  open_editor("jj-describe-" .. rev, description, {
    "# Describe revision " .. rev,
    "# Lines starting with # are ignored",
    "# :w to save, q to abort",
    "# Empty description clears message",
  }, function(text)
    local result = init.run_jj({ "describe", rev, "-m", text })
    if result then
      vim.notify("Description updated for " .. rev, vim.log.levels.INFO)
      init.refresh_views()
      return true
    end
    return false
  end, { setup_keymaps = setup_keymaps })
end

function M.commit()
  local init = require("jj-fugitive")

  local description = get_description("@")

  open_editor("jj-commit", description, {
    "# Commit message (describe @ then create new change)",
    "# Lines starting with # are ignored",
    "# :w to save, q to abort",
  }, function(text)
    local result = init.run_jj({ "commit", "-m", text })
    if result then
      vim.notify("Committed: " .. text:match("^[^\n]*"), vim.log.levels.INFO)
      init.refresh_views()
      return true
    end
    return false
  end, { setup_keymaps = setup_keymaps })
end

return M
