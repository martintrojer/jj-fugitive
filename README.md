# jj-fugitive.nvim

A Neovim plugin that brings vim-fugitive-style version control integration for Jujutsu (jj).

## Features

- **Multi-level smart completion** - Intelligent tab completion for nested jj commands (`:J git <Tab>`, `:J bookmark <Tab>`)
- **Improved diff navigation** - Intuitive keybindings with vim-fugitive compatibility (Enter shows diff, Tab toggles views)
- **Enhanced diff viewer** - Both unified and side-by-side diff formats with seamless toggle functionality
- **Interactive status buffer** - vim-fugitive-style interface with logical file operations (o=open, s=split, v=vsplit, t=tab)
- **Native jj log view** - Authentic jj formatting with symbols (@, ◆, ○, │, ~) and interactive navigation
- **Repository-aware commands** - Works seamlessly from any subdirectory within a jj repository
- **Seamless jj integration** - Direct access to all jj functionality with modern syntax support
- **ANSI color processing** - Preserves authentic jj colorization across all views
- **Auto-refresh** - Status buffer updates automatically after state changes

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
| `:J browse` | Open current file/lines on remote (GBrowse-like) |
| `:JBrowse` | Shorthand for `:J browse` |
| `:J <any-jj-command>` | Execute any jj command with smart completion |

## Usage Examples

### Multi-Level Smart Completion

The `:J` command provides intelligent tab completion at every nesting level:

```vim
" Show status (default)
:J

" Level 1: Commands
:J <space>                " → Shows: abandon, absorb, bookmark, commit, diff, log, status...
:J s<tab>                 " → Shows: show, squash, status...

" Level 2: Subcommands
:J git <tab>              " → Shows: push, fetch, pull, clone, remote...
:J bookmark <tab>         " → Shows: list, create, delete, set, move...

" Level 3: Flags
:J git push <tab>         " → Shows: --bookmark, --branch, --help...
:J bookmark create <tab>  " → Shows: --revision, --help...

" Run any jj command with full argument support
:J log -T compact
:J commit -m "Fix bug"
:J new -m "Start feature"
:J git push --bookmark main
:J bookmark create feature --revision @
```

### Interactive Status Buffer (Improved!)

```vim
" Open interactive status buffer
:J
:J status

" Enhanced keybindings in status buffer:
" <CR>     - Show diff for file (NEW: vim-fugitive standard)
" o        - Open file in editor
" s        - Open file in horizontal split
" v        - Open file in vertical split
" t        - Open file in new tab
" d        - Show unified diff for file
" D        - Show side-by-side diff for file
" Tab      - Toggle between unified/side-by-side diff
" r        - Restore file from parent revision (jj restore)
" a        - Absorb changes into mutable ancestors (jj absorb)
" cc       - Commit with message
" ca       - Amend current commit description
" l        - Show log view
" R        - Reload status
" b/q      - Close status buffer
" g?       - Show help
```

### Native jj Log View

```vim
" Show interactive log with authentic jj formatting
:J log

" In log buffer (preserves native jj symbols: @, ◆, ○, │, ~):
" <CR>/o   - Show commit details and changes
" d        - Show unified diff for this commit
" D        - Show side-by-side diff for this commit
" Tab      - Toggle between diff and commit details
" e        - Edit at this commit (jj edit)
" n        - Create new commit after this one (jj new)
" r        - Rebase current commit onto this one (jj rebase)
" A        - Abandon commit (jj abandon)
" s        - Squash commit into its parent (jj squash)
" =, +     - Expand log view (show 50 more commits)
" R        - Refresh log view
" b/q      - Close log view
" g?       - Show help
```

### Enhanced Diff Viewer with Toggle Functionality

```vim
" Show diff for current buffer
:J diff

" Show diff for specific file
:J diff src/main.rs

" In diff buffer:
" Tab      - Toggle between unified and side-by-side view
" s        - Switch to side-by-side view
" u        - Switch to unified view
" f        - Select diff format (git, color-words, etc.)
" [c       - Previous change
" ]c       - Next change
" r        - Refresh diff
" o        - Open file in editor
" b/q      - Close diff buffer
" g?       - Show help

### Browse current file on remote (GBrowse-like)

```vim
" Open current file and line (or visual selection) on the remote host
:J browse

" Shorthand command
:JBrowse
```
Supports SSH/HTTPS remotes (GitHub/GitLab-style), prefers the `main` bookmark for
the revision, and falls back to the current `@` commit when needed.
```

## Documentation

See the [doc/](doc/) folder for comprehensive documentation:

- **[User Guide](doc/README.md)** - Complete usage documentation with current features
- **[Enhanced Diff](doc/enhanced-diff.md)** - Detailed diff improvements and migration guide
- **[Development](doc/development.md)** - Setup, testing, and contribution guide
- **[Vim Help](doc/jj-fugitive.txt)** - Integrated vim help (`:help jj-fugitive`)

## Contributing

See [doc/development.md](doc/development.md) for detailed development and contribution instructions.

## License

MIT
