# Enhanced Diff Navigation and Views

The jj-fugitive plugin provides an enhanced diff viewing experience with improved navigation, toggle functionality, and both unified and side-by-side views.

## Navigation Improvements

### Intuitive Keybindings

jj-fugitive now uses intuitive, logical keybindings that follow vim-fugitive conventions:

#### Status Buffer (NEW BEHAVIOR!)
| Key | Action | Previous Behavior |
|-----|--------|-------------------|
| `<CR>` | Show diff for file | ~~Open file~~ (now shows diff - vim-fugitive standard) |
| `o` | Open file in editor | New logical mapping |
| `s` | Open file in horizontal split | New logical mapping |
| `v` | Open file in vertical split | New logical mapping |
| `t` | Open file in new tab | New logical mapping |
| `d` | Show unified diff | Simplified from confusing `dd`, `dv`, `ds` |
| `D` | Show side-by-side diff | Simplified and logical |
| `Tab` | Toggle between diff views | Universal toggle key |

#### Log Buffer
| Key | Action |
|-----|--------|
| `<CR>` | Show commit details |
| `d` | Show unified diff for commit |
| `D` | Show side-by-side diff for commit |
| `Tab` | Toggle between diff and commit details |

#### Diff Buffer  
| Key | Action |
|-----|--------|
| `Tab` | Toggle between unified and side-by-side view |
| `s` | Switch to side-by-side view |
| `u` | Switch to unified view |
| `f` | Select diff format (git, color-words, etc.) |
| `[c` | Previous change |
| `]c` | Next change |
| `r` | Refresh diff |
| `o` | Open file in editor |
| `q` | Close diff view |
| `g?` | Show help |

## Diff View Types

### Unified Diff View

The default unified diff view shows changes in a single pane with:

- **Native jj colorization**: Preserves authentic jj output colors
- **ANSI color processing**: Full color support with proper highlighting
- **Git format compatibility**: Uses `--git` flag for familiar output
- **Context options**: Configurable context lines

#### Access Unified View:
```vim
:J diff filename.txt       " Direct unified diff
# From status buffer: press 'd' on a file
# From diff view: press 'u' or Tab to toggle
```

### Side-by-Side Diff View

Enhanced side-by-side view shows original and current file content:

- **Left pane**: Original file content (parent revision `@-`)
- **Right pane**: Current file content (working copy)
- **Native vim diff mode**: Uses vim's built-in diff highlighting
- **Synchronized scrolling**: Both panes scroll together
- **Proper syntax highlighting**: File type detection for both panes

#### Access Side-by-Side View:
```vim
# From status buffer: press 'D' on a file  
# From diff view: press 's' or Tab to toggle
# From log buffer: press 'D' on a commit
```

### Toggle Functionality

The universal `Tab` key provides seamless switching:

- **In Status Buffer**: Tab toggles between unified/side-by-side for selected file
- **In Log Buffer**: Tab toggles between diff and commit details
- **In Diff Buffer**: Tab toggles between unified and side-by-side views

## Visual Enhancements

### ANSI Color Processing

jj-fugitive preserves jj's native colorization through advanced ANSI processing:

- **Authentic jj colors**: Maintains original jj diff colors
- **Terminal compatibility**: Works in both GUI and terminal Neovim
- **Color code parsing**: Proper handling of ANSI escape sequences
- **Highlight groups**: Custom syntax highlighting for enhanced readability

### Format Options

Multiple diff formats available through the `f` key:

| Format | Description |
|--------|-------------|
| Git format (default) | Standard git-style diff output |
| Color words | Word-level highlighting of changes |
| Default jj format | Native jj diff output |
| Context variations | Different amounts of context lines |
| Whitespace options | Ignore whitespace changes |

## Usage Examples

### Enhanced Status Workflow

```bash
# Open status buffer
:J

# Navigate to a changed file and:
<CR>      # Show diff (NEW! was: open file)
Tab       # Toggle to side-by-side view
Tab       # Toggle back to unified view
d         # Force unified diff
D         # Force side-by-side diff
o         # Open file in editor
s         # Open file in horizontal split
```

### Log Navigation Workflow

```bash
# Open log view
:J log

# Navigate to a commit and:
<CR>      # Show commit details
d         # Show commit diff
D         # Show side-by-side commit diff
Tab       # Toggle between diff and details
```

### Advanced Diff Exploration

```bash
# Open specific file diff
:J diff myfile.lua

# In diff view:
Tab       # Toggle unified/side-by-side
s         # Switch to side-by-side
u         # Switch to unified
f         # Select different format
[c        # Previous change
]c        # Next change
```

## Technical Implementation

### Modern jj Syntax

jj-fugitive uses modern jj command syntax:

- **File content**: `jj file show filename -r @-` (modern syntax)
- **Diff output**: `jj diff --git --color always` for compatibility
- **Error handling**: Robust fallbacks for different jj versions

### Buffer Management

- **Unique buffer names**: Timestamped buffers prevent conflicts
- **Proper cleanup**: Automatic buffer management
- **Tab handling**: Smart tab creation and cleanup for side-by-side views
- **Window management**: Proper window focus and cursor positioning

### Toggle Logic

Intelligent toggle detection:

```lua
-- Detects current view type and switches appropriately
if vim.fn.tabpagenr("$") > 1 and current_bufname:match("jj%-diff.*%(") then
  -- Currently in side-by-side (tab view), switch to unified
  vim.cmd("tabclose")
  show_unified_diff(filename)
else
  -- Currently in unified or elsewhere, switch to side-by-side
  show_sidebyside_diff(filename)
end
```

## Benefits

### Improved User Experience

- **Vim-fugitive compatibility**: Enter key shows diff (standard behavior)
- **Logical keybindings**: Mnemonic keys (o=open, s=split, v=vsplit, t=tab)
- **Universal toggle**: Tab key works consistently across all views
- **Reduced confusion**: Simplified from confusing `dv`, `ds`, `=` keys

### Enhanced Productivity

- **Faster navigation**: Intuitive keybindings reduce cognitive load
- **Seamless switching**: Toggle between views without losing context
- **Better file operations**: Logical split/open keys for efficient workflow
- **Consistent interface**: Same patterns across status, log, and diff buffers

## Compatibility

The enhanced diff system:

- **Preserves jj workflow**: Maintains jj's change-centric model
- **Works everywhere**: Functions from any subdirectory in jj repo
- **Robust operation**: Fallback mechanisms for different environments
- **Native integration**: Uses jj's actual output and colorization

## Testing

Comprehensive test coverage includes:

```bash
# Run specific diff navigation tests
./tests/test_improved_diff_navigation.lua
./tests/test_vim_fugitive_alignment.lua

# Run enhanced diff tests  
./tests/test_improved_diff.lua

# Run full suite
./tests/run_tests.sh
```

## Migration Guide

### What Changed

| Old Behavior | New Behavior | Reason |
|--------------|--------------|---------|
| `<CR>` opens file | `<CR>` shows diff | vim-fugitive standard |
| `dd` shows diff | `d` shows diff | Simplified and logical |
| `dv` vertical diff | `D` side-by-side | More intuitive |
| `ds` horizontal diff | *(removed)* | Confusing, side-by-side is better |
| `=` inline diff | `Tab` toggle | Universal toggle key |
| No file opening keys | `o`, `s`, `v`, `t` | Logical mnemonics |

### Quick Adaptation

- **Enter key**: Now shows diff instead of opening file (vim-fugitive standard)
- **File opening**: Use `o` (open), `s` (split), `v` (vsplit), `t` (tab)
- **Diff access**: Use `d` (unified) or `D` (side-by-side)
- **Toggle**: Universal `Tab` key works everywhere

## See Also

- [Status Buffer Documentation](jstatus.md) - Interactive status buffer
- [Log View Documentation](jlog.md) - Native jj log integration
- [J Command Documentation](j-command.md) - Universal command interface
- [Main Documentation](README.md) - Complete feature overview