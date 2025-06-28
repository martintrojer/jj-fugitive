# jj-fugitive.nvim

A Neovim plugin that brings vim-fugitive-style version control integration for Jujutsu (jj).

## Features

- Seamless jj integration within Neovim
- Familiar command interface inspired by vim-fugitive
- Support for core jj operations: status, log, diff, commit, and more
- Navigation commands for revision history

## Requirements

- Neovim 0.8+
- [Jujutsu](https://github.com/martinvonz/jj) installed and available in PATH

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "your-username/jj-fugitive.nvim",
  config = function()
    -- Plugin loads automatically
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use "your-username/jj-fugitive.nvim"
```

## Commands

| Command | Description |
|---------|-------------|
| `:Jj` | Show jj status (default) or run arbitrary jj command |
| `:JjStatus` | Show repository status |
| `:JjLog` | Show revision history |
| `:JjDiff` | Show diff between revisions |
| `:JjCommit` | Create a commit |
| `:JjNew` | Create a new change |
| `:JjNext` | Move to next child revision |
| `:JjPrev` | Move to parent revision |
| `:JjEdit` | Set specific revision as working copy |
| `:JjBookmark` | List and manage bookmarks |

## Examples

```vim
" Show status
:JjStatus

" Show log with custom format
:JjLog -T compact

" Show diff for current change
:JjDiff

" Create a new change
:JjNew

" Move to parent revision
:JjPrev
```

## Development

### Running Tests

```bash
# Install dependencies
luarocks install busted
git clone https://github.com/nvim-lua/plenary.nvim /tmp/plenary.nvim

# Run tests
export PLENARY_DIR=/tmp/plenary.nvim
nvim --headless --noplugin -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"
```

### Linting and Formatting

```bash
# Install tools
luarocks install luacheck
# Install stylua from GitHub releases

# Run linting
luacheck .

# Format code
stylua .
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and linting
5. Submit a pull request

## License

MIT