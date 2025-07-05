# jj-fugitive Documentation

Welcome to the jj-fugitive documentation! This plugin brings vim-fugitive-style version control integration for Jujutsu (jj) to Neovim.

## Quick Start

1. **Installation**: See the main [README](../README.md) for installation instructions
2. **Basic usage**: Open a jj repository and run `:J` to show interactive status
3. **Smart completion**: Type `:J <space>` to see all available jj commands with tab completion
4. **Interactive workflow**: Use keybindings in the status buffer to manage changes

## Documentation Index

### Core Features

- **[:J Command](j-command.md)** - Universal jj command with multi-level smart completion
- **[Status Buffer](jstatus.md)** - Interactive status buffer with improved diff navigation
- **[Diff Viewer](jdiff.md)** - Enhanced diff viewer with toggle functionality and side-by-side support
- **[Log Viewer](jlog.md)** - Native jj log view with authentic formatting (coming soon)
- **[Enhanced Diff](enhanced-diff.md)** - Detailed diff improvements documentation

### Guides

- **[Getting Started](getting-started.md)** - Step-by-step setup and first use (coming soon)
- **[Workflows](workflows.md)** - Common development workflows (coming soon)
- **[Configuration](configuration.md)** - Customization options (coming soon)

### Advanced

- **[Development](development.md)** - Development and contribution guide
- **[API Reference](api.md)** - Lua API for extending functionality (coming soon)
- **[Troubleshooting](troubleshooting.md)** - Common issues and solutions (coming soon)

## Currently Available

### ✅ Implemented Features

- **:J Command** - Universal jj interface with multi-level smart completion
  - **Multi-Level Completion**: Tab completion works at every nesting level
    - `:J git <Tab>` → shows git subcommands (push, fetch, clone, etc.)
    - `:J git push <Tab>` → shows git push flags (--bookmark, --branch, etc.)
    - `:J bookmark <Tab>` → shows bookmark subcommands (list, create, delete, etc.)
    - `:J bookmark create <Tab>` → shows bookmark create flags and options
  - Context-aware suggestions (bookmarks, files, etc.)
  - Automatic status buffer refresh after state changes
  - Support for all jj operations with full argument passing

- **Status Buffer** (`:J` or `:J status`) - Enhanced interactive interface
  - **Improved Diff Navigation**: Enter now shows diff (vim-fugitive standard)
  - Intuitive keybindings: `o`=open file, `s`=split, `v`=vsplit, `t`=tab
  - Enhanced diff operations: `d`=unified diff, `D`=side-by-side diff
  - Universal `Tab` key toggles between diff views
  - jj-specific operations: `r`=restore, `a`=absorb, `cc`=commit, `ca`=amend
  - Real-time status updates and syntax highlighting

- **Log View** (`:J log`) - Native jj log browser
  - **Authentic jj formatting**: Preserves native symbols (@, ◆, ○, │, ~)
  - **Interactive navigation**: Enter=details, `d`=diff, `D`=side-by-side
  - **Tab toggle**: Switch between diff and commit details
  - **Expandable view**: `=` or `+` keys show more commits
  - **Commit operations**: `e`=edit, `n`=new, `r`=rebase, `A`=abandon, `s`=squash

- **Diff Viewer** (`:J diff`) - Enhanced diff visualization
  - **Unified and side-by-side** diff formats with native jj colorization
  - **Tab toggle**: Switch between unified/side-by-side views
  - **Quick access**: `s`=side-by-side, `u`=unified, `f`=format selector
  - **Navigation**: `[c`/`]c` for change navigation
  - **ANSI color processing**: Full color support across all views

### 🔧 Architecture

- **6 Core Modules**: ansi.lua, completion.lua, diff.lua, init.lua, log.lua, status.lua
- **50+ Functions**: Comprehensive functionality across all modules
- **29 Test Files**: Extensive test coverage with intelligent discovery
- **Native jj Integration**: Preserves authentic jj output formatting and colors
- **Repository Detection**: Works from any subdirectory within jj repo

## Quick Reference

### Most Used Commands

```vim
:J                      " Show interactive status buffer (default)
:J <space>              " Show all available jj commands with completion
:J status               " Show interactive status buffer
:J log                  " Show native jj log view
:J diff                 " Show diff for current buffer
:J diff [file]          " Show diff for specific file
:J commit -m "msg"      " Commit with message
:J new -m "msg"         " Create new change
```

### Status Buffer Keybindings (Improved!)

```
<CR>   - Show diff for file (NEW: was open file)
o      - Open file in editor
s      - Open file in horizontal split
v      - Open file in vertical split
t      - Open file in new tab
d      - Show unified diff for file
D      - Show side-by-side diff for file
Tab    - Toggle between unified/side-by-side diff
r      - Restore file from parent revision (jj restore)
a      - Absorb changes into mutable ancestors (jj absorb)
cc     - Commit changes with message prompt
ca     - Amend current commit description
l      - Show log view
R      - Reload status
q      - Close status buffer
g?     - Show help
```

### Log Buffer Keybindings

```
<CR>/o - Show commit details and changes
d      - Show unified diff for this commit
D      - Show side-by-side diff for this commit
Tab    - Toggle between diff and commit details
e      - Edit at this commit (jj edit)
n      - Create new commit after this one (jj new)
r      - Rebase current commit onto this one (jj rebase)
A      - Abandon commit (jj abandon)
s      - Squash commit into its parent (jj squash)
=, +   - Expand log view (show more commits)
R      - Refresh log view
q      - Close log view
g?     - Show help
```

### Diff Buffer Keybindings

```
Tab    - Toggle between unified and side-by-side view
s      - Switch to side-by-side view
u      - Switch to unified view
f      - Select diff format (git, color-words, etc.)
[c     - Previous change
]c     - Next change
r      - Refresh diff
o      - Open file in editor
q      - Close diff buffer
g?     - Show help
```

## Philosophy

jj-fugitive follows the same design principles as vim-fugitive but adapted for jj:

1. **Minimal keystrokes** - Common operations should be fast
2. **Contextual interface** - Commands work on the item under cursor
3. **Non-intrusive** - Doesn't change your normal Neovim workflow
4. **jj-native** - Preserves authentic jj output and workflow patterns
5. **Extensible** - Built with Lua for easy customization

## Getting Help

- **In Neovim**: Use `:help jj-fugitive`
- **GitHub Issues**: [Report bugs or request features](https://github.com/martintrojer/jj-fugitive.nvim/issues)
- **Documentation**: Browse this doc/ folder for detailed guides
- **Buffer help**: Press `g?` in any jj-fugitive buffer for context-specific help

## Examples

### Enhanced Completion Workflow

```vim
# Multi-level completion examples
:J <space>                    " See all jj commands
:J git <Tab>                  " Shows: push, fetch, pull, clone, remote, etc.
:J git push <Tab>             " Shows: --bookmark, --branch, --help, etc.
:J bookmark <Tab>             " Shows: list, create, delete, set, move, etc.
:J bookmark create <Tab>      " Shows: --revision, --help, etc.
:J log <Tab>                  " Shows: --limit, --template, -r, --help, etc.

# Common operations with completion
:J status                     " Interactive status buffer
:J commit -m "Fix bug"        " Quick commit
:J new -m "Start feature"     " Create new change
:J log -T compact -r main..@  " Show recent changes
```

### Improved Status Workflow

```bash
# In your jj repository
nvim

# In Neovim
:J

# In the status buffer (NEW BEHAVIOR!)
# - Press Enter on a file to see its diff (vim-fugitive standard)
# - Press 'o' on a file to open it in editor
# - Press 's' to open in horizontal split, 'v' for vertical split
# - Press 'd' for unified diff, 'D' for side-by-side diff
# - Press Tab to toggle between diff views
# - Press 'cc' to commit, 'ca' to amend
# - Press 'r' to restore file, 'a' to absorb changes
```

### Log Navigation Workflow

```vim
:J log                        " Open native jj log view
# In log view:
# - Press Enter on a commit to see details
# - Press 'd' to see commit diff, 'D' for side-by-side
# - Press Tab to toggle between diff and details
# - Press '=' or '+' to expand view (show more commits)
# - Press 'e' to edit at commit, 'n' to create new commit
```

### Diff View Workflow

```vim
:J diff myfile.lua            " View diff for specific file
# In diff view:
# - Press Tab to toggle unified/side-by-side
# - Press 's' for side-by-side, 'u' for unified
# - Press '[c' and ']c' to navigate changes
# - Press 'f' to select different formats
```

## Version History

---

*This documentation reflects the current state of jj-fugitive with all recent improvements including enhanced diff navigation, multi-level completion, and native jj log integration.*
