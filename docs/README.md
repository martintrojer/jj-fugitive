# jj-fugitive Documentation

Welcome to the jj-fugitive documentation! This plugin brings vim-fugitive-style version control integration for Jujutsu (jj) to Neovim.

## Quick Start

1. **Installation**: See the main [README](../README.md) for installation instructions
2. **Basic usage**: Open a jj repository and run `:JStatus`
3. **Interactive workflow**: Use keybindings in the status buffer to manage changes

## Documentation Index

### Core Features

- **[:JStatus](jstatus.md)** - Interactive status buffer with file management
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

- **:JStatus** - Full-featured interactive status buffer
  - File status display with syntax highlighting
  - Keybindings for common operations (cc, new, dd, o, r, q)
  - Integration with jj commands
  - Real-time status updates

### 🚧 Work in Progress

- **:JLog** - Interactive log browser
- **:JDiff** - Enhanced diff viewer
- **:JCommit** - Commit interface
- **:JBookmark** - Bookmark management

### 📋 Planned Features

- **:JEdit** - Revision editing
- **:JNext/:JPrev** - Revision navigation
- **:JNew** - Change creation
- Configuration system
- Custom keybinding support
- Integration with telescope.nvim

## Quick Reference

### Most Used Commands

```vim
:JStatus    " Open interactive status buffer
:J          " Shorthand for :JStatus (when no args)
:JLog       " Show revision history (basic)
:JDiff      " Show diff (basic)
```

### Status Buffer Keybindings

```
r    - Reload status
cc   - Commit changes
new  - Create new change
dd   - Diff file under cursor
o    - Open file under cursor
q    - Quit status buffer
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

### Basic Status Workflow

```bash
# In your jj repository
nvim

# In Neovim
:JStatus

# In the status buffer
# - Press 'o' on a file to edit it
# - Press 'dd' on a file to see its diff  
# - Press 'cc' to commit your changes
# - Press 'new' to start a new change
```

### Integration with Splits

```vim
" Open status in vertical split
:vsplit | JStatus

" Open status in horizontal split  
:split | JStatus
```

## Version History

- **v0.1.0** - Initial release with :JStatus functionality
- **v0.2.0** - Enhanced status buffer with full keybinding support (current)

---

*This documentation is a work in progress. More sections will be added as features are implemented.*