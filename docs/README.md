# jj-fugitive Documentation

Welcome to the jj-fugitive documentation! This plugin brings vim-fugitive-style version control integration for Jujutsu (jj) to Neovim.

## Quick Start

1. **Installation**: See the main [README](../README.md) for installation instructions
2. **Basic usage**: Open a jj repository and run `:J` to show interactive status
3. **Smart completion**: Type `:J <space>` to see all available jj commands with tab completion
4. **Interactive workflow**: Use keybindings in the status buffer to manage changes

## Documentation Index

### Core Features

- **[:J Command](j-command.md)** - Universal jj command with smart completion
- **[Status Buffer](jstatus.md)** - Interactive status buffer accessed via `:J` or `:J status`  
- **[Diff Viewer](jdiff.md)** - Enhanced diff viewer accessed via `:J diff`
- **[Commands](commands.md)** - Complete command reference (coming soon)
- **[Keybindings](keybindings.md)** - All available keybindings (coming soon)

### Guides

- **[Getting Started](getting-started.md)** - Step-by-step setup and first use (coming soon)
- **[Workflows](workflows.md)** - Common development workflows (coming soon)
- **[Configuration](configuration.md)** - Customization options (coming soon)

### Advanced

- **[Remote Testing](remote-testing.md)** - Automated testing with Neovim remote API
- **[Development](development.md)** - Development and contribution guide
- **[API Reference](api.md)** - Lua API for extending functionality (coming soon)
- **[Troubleshooting](troubleshooting.md)** - Common issues and solutions (coming soon)

## Currently Available

### ✅ Implemented Features

- **:J Command** - Universal jj interface with smart completion
  - Intelligent tab completion for all jj commands and flags
  - Context-aware suggestions (bookmarks, files, etc.)
  - Automatic status buffer refresh after state changes
  - Support for all jj operations with full argument passing

- **Status Buffer** (`:J` or `:J status`) - Full-featured interactive interface
  - File status display with syntax highlighting
  - Keybindings for common operations (cc, new, dd, o, r, q/gq)
  - Integration with diff viewer
  - Real-time status updates

- **Diff Viewer** (`:J diff`) - Enhanced diff visualization
  - Unified and side-by-side diff formats
  - Toggle between formats with 's' key
  - Current buffer or file-specific diffs with syntax highlighting
  - Seamless integration with status buffer

### 📋 All Features Now Use :J

All jj operations are available through the universal `:J` command:

- **Commands**: `:J log`, `:J commit`, `:J bookmark`, `:J edit`, `:J next`, `:J prev`, `:J new`, etc.
- **Smart completion**: All commands and flags are intelligently completed
- **Full jj functionality**: Any jj command can be used with `:J`

## Quick Reference

### Most Used Commands

```vim
:J                    " Show interactive status buffer (default)
:J <space>            " Show all available jj commands
:J status             " Show interactive status buffer
:J diff               " Show diff for current buffer
:J diff [file]        " Show diff for specific file
:J commit -m "msg"    " Commit with message
:J log -T compact     " Show log with custom template
:J new -m "msg"       " Create new change
```

### Status Buffer Keybindings

```
r    - Reload status
cc   - Commit changes with message prompt
new  - Create new change
dd   - Show diff for file under cursor
o    - Open file under cursor
q/gq - Close status buffer
```

### Diff Buffer Keybindings

```
s    - Toggle between unified and side-by-side view
q    - Close diff buffer
```

## Philosophy

jj-fugitive follows the same design principles as vim-fugitive:

1. **Minimal keystrokes** - Common operations should be fast
2. **Contextual interface** - Commands work on the item under cursor
3. **Non-intrusive** - Doesn't change your normal Neovim workflow
4. **Extensible** - Built with Lua for easy customization

## Getting Help

- **In Neovim**: Use `:help jj-fugitive` (coming soon)
- **GitHub Issues**: [Report bugs or request features](https://github.com/username/jj-fugitive.nvim/issues)
- **Documentation**: Browse this doc/ folder for detailed guides

## Examples

### Smart Completion Workflow

```vim
# Basic usage with completion
:J <space>                    " See all jj commands
:J st<tab>                    " Complete to 'status'
:J commit <space>             " See all commit flags
:J log --template <space>     " See template options

# Common operations
:J status                     " Interactive status buffer
:J commit -m "Fix bug"        " Quick commit
:J new -m "Start feature"     " Create new change
:J log -T compact -r main..@  " Show recent changes
```

### Interactive Status Workflow

```bash
# In your jj repository
nvim

# In Neovim
:J

# In the status buffer
# - Press 'o' on a file to edit it
# - Press 'dd' on a file to see its diff  
# - Press 'cc' to commit your changes
# - Press 'new' to start a new change
# - Press 'r' to reload status
```

### Integration with Splits

```vim
" Open status in vertical split
:vsplit | J

" Open status in horizontal split  
:split | J
```

## Version History

- **v0.1.0** - Initial release with :JStatus functionality
- **v0.2.0** - Enhanced status buffer with full keybinding support  
- **v0.3.0** - Smart completion system and universal :J command (current)
- **v0.4.0** - Enhanced diff viewer with side-by-side support (current)

---

*This documentation is a work in progress. More sections will be added as features are implemented.*