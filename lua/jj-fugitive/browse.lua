local M = {}

local init = require("jj-fugitive.init")

-- Parse a git remote URL into a web base and repo info
-- Supports: git@github.com:user/repo.git, https://github.com/user/repo(.git), ssh://git@github.com/user/repo.git
function M.parse_remote_url(url)
  if not url or url == "" then
    return nil, "Empty remote URL"
  end

  local host, owner, repo

  -- git@host:owner/repo.git
  host, owner, repo = url:match("^git@([^:]+):([^/]+)/([^%.]+)%.?git?$")
  if host and owner and repo then
    return {
      host = host,
      owner = owner,
      repo = repo,
      web_base = string.format("https://%s/%s/%s", host, owner, repo),
    }
  end

  -- ssh://git@host/owner/repo(.git)
  host, owner, repo = url:match("^ssh://git@([^/]+)/([^/]+)/([^%./]+)%.?git?/?$")
  if host and owner and repo then
    return {
      host = host,
      owner = owner,
      repo = repo,
      web_base = string.format("https://%s/%s/%s", host, owner, repo),
    }
  end

  -- http(s)://host/owner/repo(.git)
  local scheme
  scheme, host, owner, repo = url:match("^(https?)://([^/]+)/([^/]+)/([^/]+)$")
  if host and owner and repo then
    repo = repo:gsub("%.git$", "")
    repo = repo:gsub("/$", "")
    return {
      host = host,
      owner = owner,
      repo = repo,
      web_base = string.format("%s://%s/%s/%s", scheme, host, owner, repo),
    }
  end
  if host and owner and repo then
    return {
      host = host,
      owner = owner,
      repo = repo,
      web_base = string.format("%s://%s/%s/%s", scheme, host, owner, repo),
    }
  end

  return nil, "Unsupported or unrecognized remote URL: " .. url
end

-- Build a web URL for a file on common forges (GitHub/GitLab-like)
-- provider is inferred from host; for GitHub: /blob/<rev>/<path>#Lstart-Lend
function M.build_file_url(web_base, host, path, rev, line_start, line_end)
  if not web_base or not host or not path or not rev then
    return nil, "Missing parameters to build URL"
  end

  local encoded_path = path:gsub(" ", "%%20")
  local url

  if host:match("github%.com$") then
    url = string.format("%s/blob/%s/%s", web_base, rev, encoded_path)
    if line_start and line_end and line_start ~= line_end then
      url = string.format("%s#L%d-L%d", url, line_start, line_end)
    elseif line_start then
      url = string.format("%s#L%d", url, line_start)
    end
  elseif host:match("gitlab%.com$") then
    url = string.format("%s/-/blob/%s/%s", web_base, rev, encoded_path)
    if line_start and line_end and line_start ~= line_end then
      url = string.format("%s#L%d-%d", url, line_start, line_end)
    elseif line_start then
      url = string.format("%s#L%d", url, line_start)
    end
  else
    -- Fallback to GitHub-style
    url = string.format("%s/blob/%s/%s", web_base, rev, encoded_path)
    if line_start and line_end and line_start ~= line_end then
      url = string.format("%s#L%d-L%d", url, line_start, line_end)
    elseif line_start then
      url = string.format("%s#L%d", url, line_start)
    end
  end

  return url
end

local function get_origin_url()
  local out = init.run_jj_command_from_module({ "git", "remote", "list" })
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
  -- Prefer 'main' bookmark if it exists
  local bl = init.run_jj_command_from_module({ "bookmark", "list" })
  if bl and bl:match("^main:") or (bl and bl:match("\nmain:")) then
    return "main"
  end

  -- Fallback to current git commit id (short) of @
  local log = init.run_jj_command_from_module({ "log", "-r", "@", "--no-graph", "--limit", "1" })
  if log then
    local hash = log:match("([a-f0-9]+)%s*$")
    if hash then
      return hash
    end
  end
  return nil
end

local function get_relative_path()
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    return nil
  end
  local root = init.get_repo_root()
  if not root then
    return nil
  end
  local rel = file
  if rel:find(root, 1, true) == 1 then
    rel = rel:sub(#root + 2)
  end
  return rel
end

local function get_line_range()
  local start_line = nil
  local end_line = nil
  local mode = vim.fn.mode()

  if mode:match("^[vV\22]") then
    -- Visual selection
    local s = vim.fn.getpos("<")[2]
    local e = vim.fn.getpos(">")[2]
    if s and e then
      if s <= e then
        start_line, end_line = s, e
      else
        start_line, end_line = e, s
      end
    end
  else
    -- Current cursor line
    start_line = vim.fn.line(".")
  end

  return start_line, end_line
end

-- Open URL using OS default handler; fallback to echo and yank to clipboard
local function open_url(url)
  if not url then
    return false
  end
  local ok = false
  if vim.fn.has("mac") == 1 then
    ok = (vim.fn.system({ "open", url }) ~= nil)
  elseif vim.fn.executable("xdg-open") == 1 then
    ok = (vim.fn.system({ "xdg-open", url }) ~= nil)
  elseif vim.fn.has("win32") == 1 then
    ok = (vim.fn.system({ "cmd", "/c", "start", url }) ~= nil)
  end
  if not ok then
    vim.fn.setreg("+", url)
    vim.api.nvim_echo({ { "URL copied to clipboard: ", "MoreMsg" }, { url, "Underlined" } }, false, {})
  end
  return true
end

-- Main entrypoint: open current file/lines at remote
function M.browse()
  local remote_url, err = get_origin_url()
  if not remote_url then
    vim.api.nvim_err_writeln(err or "No git remote found")
    return
  end
  local remote, perr = M.parse_remote_url(remote_url)
  if not remote then
    vim.api.nvim_err_writeln(perr)
    return
  end

  local rel = get_relative_path()
  if not rel then
    vim.api.nvim_err_writeln("No file in current buffer or not inside repository")
    return
  end

  local rev = get_default_rev()
  if not rev then
    vim.api.nvim_err_writeln("Unable to determine revision (no 'main' and no current commit)")
    return
  end

  local s, e = get_line_range()
  local url = M.build_file_url(remote.web_base, remote.host, rel, rev, s, e)
  if not url then
    vim.api.nvim_err_writeln("Failed to build browse URL")
    return
  end

  open_url(url)
end

return M
