local M = {}

local core_browse = require("fugitive-core.views.browse")

local function get_origin_url()
  local init = require("jj-fugitive")
  local out = init.run_jj({ "git", "remote", "list" })
  if not out then
    return nil, "Failed to list git remotes"
  end
  for line in out:gmatch("[^\n]+") do
    local name, url = line:match("^(%S+)%s+(%S+)%s*$")
    if name == "origin" and url then
      return url
    end
  end
  -- fallback: first remote
  local name, url = out:match("^(%S+)%s+(%S+)%s*$")
  return url, url and ("Using remote '" .. name .. "'") or "No git remote found"
end

local function get_default_rev()
  local init = require("jj-fugitive")
  local bl = init.run_jj({ "bookmark", "list" })
  if bl and (bl:match("^main:") or bl:match("\nmain:")) then
    return "main"
  end

  local log = init.run_jj({ "log", "-r", "@", "--no-graph", "--limit", "1" })
  if log then
    local hash = log:match("([a-f0-9]+)%s*$")
    if hash then
      return hash
    end
  end
  return nil
end

local function get_relative_path()
  local init = require("jj-fugitive")
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    return nil
  end
  local root = init.repo_root()
  if not root then
    return nil
  end
  local rel = file
  if rel:find(root, 1, true) == 1 then
    rel = rel:sub(#root + 2)
  end
  return rel
end

function M.browse()
  local ui = require("jj-fugitive.ui")
  local remote_url, err = get_origin_url()
  if not remote_url then
    ui.err(err or "No git remote found")
    return
  end
  local remote, perr = core_browse.parse_remote_url(remote_url)
  if not remote then
    ui.err(perr)
    return
  end

  local rel = get_relative_path()
  if not rel then
    ui.err("No file in current buffer or not inside repository")
    return
  end

  local rev = get_default_rev()
  if not rev then
    ui.err("Unable to determine revision (no 'main' and no current commit)")
    return
  end

  local s, e = core_browse.line_range()
  local url = core_browse.build_file_url(remote, rel, rev, s, e)
  if not url then
    ui.err("Failed to build browse URL")
    return
  end

  core_browse.open_url(url)
end

return M
