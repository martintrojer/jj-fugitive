local M = {}

--- Get the description text for a revision using jj's template engine.
local function get_description(init, rev)
  local result = init.run_jj({ "log", "-r", rev, "--no-graph", "-T", "description" })
  return result and result:gsub("%s+$", "") or ""
end

--- Open a scratch buffer for editing a commit message.
--- On :w, runs the given save_fn with the buffer contents.
--- Returns the buffer number.
local function open_editor(buffer_name, initial_text, help_lines, save_fn)
  local ui = require("jj-fugitive.ui")

  local bufnr = ui.create_scratch_buffer({
    name = buffer_name,
    buftype = "acwrite",
    filetype = "gitcommit",
    modifiable = true,
  })

  -- Set initial content: help comments + text
  local lines = {}
  for _, h in ipairs(help_lines) do
    table.insert(lines, h)
  end
  table.insert(lines, "")
  for _, l in ipairs(vim.split(initial_text, "\n")) do
    table.insert(lines, l)
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- BufWriteCmd: filter comments, call save_fn
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = bufnr,
    callback = function()
      local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local filtered = {}
      for _, line in ipairs(buf_lines) do
        if not line:match("^%s*#") then
          table.insert(filtered, line)
        end
      end

      local text = table.concat(filtered, "\n"):gsub("^%s+", ""):gsub("%s+$", "")

      if save_fn(text) then
        vim.api.nvim_buf_set_option(bufnr, "modified", false)
        vim.cmd(ui.close_cmd())
      end
    end,
  })

  -- q to abort (close without saving)
  ui.map(bufnr, "n", "q", function()
    vim.api.nvim_buf_set_option(bufnr, "modified", false)
    vim.cmd(ui.close_cmd())
  end)

  -- Open in a new pane
  ui.open_pane()
  vim.api.nvim_win_set_buf(0, bufnr)

  -- Position cursor after help comments
  vim.api.nvim_win_set_cursor(0, { #help_lines + 2, 0 })

  return bufnr
end

--- Open a describe buffer for the given revision.
function M.describe(rev)
  rev = rev or "@"
  local init = require("jj-fugitive")

  local description = get_description(init, rev)

  open_editor("jj-describe-" .. rev, description, {
    "# Describe revision " .. rev,
    "# Lines starting with # are ignored",
    "# :w to save, q to abort",
    "# Empty description clears message",
  }, function(text)
    local result = init.run_jj({ "describe", rev, "-m", text })
    if result then
      print("Description updated for " .. rev)
      init.refresh_log()
      return true
    end
    return false
  end)
end

--- Open a commit buffer (describe + new).
function M.commit()
  local init = require("jj-fugitive")

  local description = get_description(init, "@")

  open_editor("jj-commit", description, {
    "# Commit message (describe @ then create new change)",
    "# Lines starting with # are ignored",
    "# :w to save, q to abort",
  }, function(text)
    local result = init.run_jj({ "commit", "-m", text })
    if result then
      print("Committed: " .. text:match("^[^\n]*"))
      init.refresh_log()
      return true
    end
    return false
  end)
end

return M
