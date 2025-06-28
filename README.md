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
| `:J` | Show jj status (default) or run arbitrary jj command |
| `:JStatus` | Show repository status |
| `:JLog` | Show revision history |
| `:JDiff` | Show diff between revisions |
| `:JCommit` | Create a commit |
| `:JNew` | Create a new change |
| `:JNext` | Move to next child revision |
| `:JPrev` | Move to parent revision |
| `:JEdit` | Set specific revision as working copy |
| `:JBookmark` | List and manage bookmarks |

## Examples

```vim
" Show status
:JStatus

" Show log with custom format
:JLog -T compact

" Show diff for current change
:JDiff

" Create a new change
:JNew

" Move to parent revision
:JPrev
```

## Documentation

See the [docs/](docs/) folder for comprehensive documentation:

- **[User Guide](docs/README.md)** - Complete usage documentation
- **[Status Buffer](docs/jstatus.md)** - Detailed `:JStatus` guide with keybindings
- **[Development](docs/development.md)** - Setup, testing, and contribution guide

## Contributing

See [docs/development.md](docs/development.md) for detailed development and contribution instructions.

## License

MIT
