# jj-fugitive.nvim

A Neovim plugin that brings vim-fugitive-style version control integration for Jujutsu (jj).

## Features

- **Smart completion system** - Intelligent tab completion for all jj commands and flags
- **Interactive status buffer** - vim-fugitive-style interface with keybindings
- **Enhanced diff viewer** - Both unified and side-by-side diff formats
- **Seamless jj integration** - Direct access to all jj functionality
- **Familiar command interface** - Inspired by vim-fugitive for easy adoption
- **Auto-refresh** - Status buffer updates automatically after state changes

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
| `:J` | Universal jj command with smart completion - shows status by default |
| `:JStatus` | Interactive status buffer with vim-fugitive-style keybindings |
| `:JDiff [file]` | Enhanced diff viewer for current buffer or specified file |

## Usage Examples

### The `:J` Command with Smart Completion

The `:J` command provides intelligent tab completion for all jj operations:

```vim
" Show status (default)
:J

" Smart completion - press space or tab to see available commands
:J <space>          " → Shows: abandon, absorb, bookmark, commit, diff, log, status...
:J s<tab>           " → Shows: show, squash, status...
:J status <space>   " → Shows: --help, --repository, --at-operation...
:J commit --<tab>   " → Shows: --message, --author, --help...

" Run any jj command with full argument support
:J log -T compact
:J commit -m "Fix bug"
:J new -m "Start feature"
:J bookmark set main
:J abandon
```

### Interactive Status Buffer (`:JStatus`)

```vim
" Open interactive status buffer
:JStatus

" Keybindings in status buffer:
" r        - Reload status
" cc       - Commit with message
" new      - Create new change
" dd       - Show diff for file under cursor
" o        - Open file under cursor
" q / gq   - Close status buffer
```

### Enhanced Diff Viewer (`:JDiff`)

```vim
" Show diff for current buffer
:JDiff

" Show diff for specific file
:JDiff src/main.rs

" Using :J command (equivalent)
:J diff              " Current buffer
:J diff src/main.rs  " Specific file

" In diff buffer:
" s        - Toggle between unified and side-by-side view
" q        - Close diff buffer
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
