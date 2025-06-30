std = "luajit"
cache = true

-- Only check our plugin code, not dependencies
include_files = {
  "lua/**/*.lua",
  "plugin/**/*.lua", 
  "tests/**/*.lua"
}

read_globals = {
  "vim",
}

globals = {
  "vim.g",
  "vim.b",
  "vim.w",
  "vim.o",
  "vim.bo",
  "vim.wo",
  "vim.go",
  "vim.env",
}

ignore = {
  "631",  -- max_line_length
  "212/_.*",  -- unused argument, for vars with "_" prefix
}