# jj-fugitive.nvim

A Neovim plugin that brings vim-fugitive-style version control integration for Jujutsu (jj).

## Features

- **Smart completion system** - Intelligent tab completion for all jj commands and flags
- **Interactive status buffer** - vim-fugitive-style interface with keybindings
- **Enhanced diff viewer** - Both unified and side-by-side diff formats with visual improvements
- **Interactive log view** - Enhanced log browser with commit operations (edit, new, rebase)
- **Repository-aware commands** - Works seamlessly from any subdirectory within a jj repository
- **Seamless jj integration** - Direct access to all jj functionality
- **Familiar command interface** - Inspired by vim-fugitive for easy adoption
- **Auto-refresh** - Status buffer updates automatically after state changes
- **Comprehensive testing** - Thoroughly tested functionality with extensive test suite

## Requirements

- Neovim 0.8+
- [Jujutsu](https://github.com/martinvonz/jj) installed and available in PATH

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "martintrojer/jj-fugitive.nvim",
  config = function()
    -- Plugin loads automatically
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use "martintrojer/jj-fugitive.nvim"
```

### Manual Installation

```bash
# Clone the repository
git clone https://github.com/martintrojer/jj-fugitive.nvim ~/.local/share/nvim/site/pack/plugins/start/jj-fugitive.nvim

# Or using jj
jj git clone https://github.com/martintrojer/jj-fugitive.nvim ~/.local/share/nvim/site/pack/plugins/start/jj-fugitive.nvim
```

## Commands

| Command | Description |
|---------|-------------|
| `:J` | Universal jj command with smart completion |
| `:J` (no args) | Show interactive status buffer |
| `:J status` | Show interactive status buffer |
| `:J log` | Show interactive log view with enhanced formatting |
| `:J diff` | Show enhanced diff for current buffer |
| `:J diff [file]` | Show enhanced diff for specified file |
| `:J <any-jj-command>` | Execute any jj command with smart completion |

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

### Interactive Status Buffer

```vim
" Open interactive status buffer
:J
:J status

" Keybindings in status buffer:
" r        - Reload status
" cc       - Commit with message
" new      - Create new change
" dd       - Show diff for file under cursor
" o        - Open file under cursor
" q / gq   - Close status buffer
```

### Interactive Log View

```vim
" Show interactive log with enhanced formatting
:J log

" In log buffer:
" Enter/o  - Show commit details
" e        - Edit at commit (jj edit)
" n        - Create new commit after this one (jj new)
" r        - Rebase current commit onto this one (jj rebase)
" d        - Show diff for commit
" q        - Close log view
" ?        - Show detailed help
```

### Enhanced Diff Viewer

```vim
" Show diff for current buffer
:J diff

" Show diff for specific file
:J diff src/main.rs

" In diff buffer:
" s        - Toggle between unified and side-by-side view
" q        - Close diff buffer
" o        - Open file in editor
" ?        - Show help
```

## Documentation

See the [doc/](doc/) folder for comprehensive documentation:

- **[User Guide](doc/README.md)** - Complete usage documentation
- **[Status Buffer](doc/jstatus.md)** - Detailed `:JStatus` guide with keybindings
- **[Development](doc/development.md)** - Setup, testing, and contribution guide
- **[Vim Help](doc/jj-fugitive.txt)** - Integrated vim help (`:help jj-fugitive`)

## Contributing

See [doc/development.md](doc/development.md) for detailed development and contribution instructions.

## License

MIT
