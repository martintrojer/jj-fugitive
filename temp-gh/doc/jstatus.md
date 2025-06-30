# Interactive Status Buffer

The `:J` and `:J status` commands open an interactive status buffer that provides a comprehensive view of your jj repository state and allows you to perform common version control operations directly from within Neovim.

## Overview

When you run `:J` or `:J status`, jj-fugitive creates a dedicated buffer that displays:
- Current working copy information
- Parent commit details  
- List of changed files with their status
- Available commands and keybindings

This interface is inspired by vim-fugitive's `:Git` command but adapted for jj's revision-centric workflow.

## Buffer Layout

```
# jj-fugitive Status

Working copy  (@) : abc123def (no description set)
Parent commit (@-): xyz789ghi main | Fix CI workflow

Working copy changes:
A new-file.txt
M existing-file.lua
D old-file.md

# Commands:
# cc = commit, new = create new change
# dd = diff file, o = open file
# r = reload status, q/gq = close
```

## File Status Indicators

| Symbol | Meaning |
|--------|---------|
| `A` | Added file (new file) |
| `M` | Modified file |
| `D` | Deleted file |
| `R` | Renamed file |

## Keybindings

### Navigation and Information
- `r` - **Reload status** - Refresh the status buffer with current repository state
- `q` / `gq` - **Quit** - Close the status buffer (vim-fugitive compatibility)

### File Operations
- `o` - **Open file** - Open the file under cursor in a new buffer
- `dd` - **Diff file** - Show enhanced diff for the file under cursor (unified/side-by-side)

### Version Control Operations
- `cc` - **Commit** - Commit current changes (prompts for commit message)
- `new` - **New change** - Create a new jj change (equivalent to `jj new`)

## Syntax Highlighting

The status buffer includes syntax highlighting to make it easier to scan:
- **Headers** (`# ...`) - Displayed as comments
- **Added files** (`A ...`) - Highlighted in green (DiffAdd)
- **Modified files** (`M ...`) - Highlighted in yellow (DiffChange)  
- **Deleted files** (`D ...`) - Highlighted in red (DiffDelete)
- **Renamed files** (`R ...`) - Highlighted in yellow (DiffChange)

## Usage Examples

### Basic Workflow

1. **Open status**: `:J` or `:J status`
2. **Review changes**: Navigate through the file list
3. **View a diff**: Position cursor on a file and press `dd` to open enhanced diff viewer
4. **Edit a file**: Position cursor on a file and press `o`
5. **Commit changes**: Press `cc` and enter commit message
6. **Create new change**: Press `new` to start working on next change

### Checking File Changes

```
# Position cursor on any changed file line like:
M lua/jj-fugitive/init.lua

# Press 'dd' to see the enhanced diff viewer with side-by-side toggle
# Press 'o' to open the file for editing
```

### Committing Changes

```
# In the status buffer, press 'cc'
# Enter commit message when prompted:
Commit message: Add interactive status buffer functionality

# Changes are committed and status refreshes automatically
```

### Creating New Changes

```
# After committing, press 'new' to create a new change
# This runs 'jj new' and refreshes the status
# You can now start working on your next set of changes
```

## Integration with jj Commands

The status buffer integrates seamlessly with jj commands and the `:J` universal command:

- **Commit**: Uses `jj commit -m "message"` (equivalent to `:J commit -m "message"`)
- **New change**: Uses `jj new` (equivalent to `:J new`)
- **Status refresh**: Uses `jj status` (equivalent to `:J status`)
- **File diff**: Uses enhanced diff viewer with `jj diff filename` and side-by-side support
- **Auto-refresh**: Status buffer automatically updates when `:J` commands change repository state

## Tips and Best Practices

1. **Keep status open**: Leave the status buffer open in a split while working
2. **Frequent refreshes**: Press `r` after making changes outside Neovim
3. **Commit often**: Use `cc` to create small, focused commits
4. **Review before commit**: Use `dd` to review changes before committing
5. **Use with splits**: Open status in a vertical split: `:vsplit | J`

## Comparison with vim-fugitive

If you're familiar with vim-fugitive, here's how jj-fugitive's status buffer compares:

| vim-fugitive | jj-fugitive | Description |
|--------------|-------------|-------------|
| `:Git` | `:J` | Main status interface |
| `s` | `cc` | Stage/commit changes |
| `cc` | `cc` | Commit changes |
| `dd` | `dd` | Diff file |
| `o` | `o` | Open file |

## Troubleshooting

### Status buffer doesn't update
- Press `r` to manually refresh
- Ensure you're in a jj repository
- Check that `jj` command is in your PATH

### Keybindings not working
- Ensure cursor is in the jj-status buffer
- Check for conflicting mappings in your config
- Verify the status buffer has focus

### Commit message prompt not appearing
- Check if you have any input plugins that might interfere
- Try the command from the command line: `:echo input("Test: ")`

## See Also

- [Main Commands](commands.md) - Overview of all jj-fugitive commands
- [Configuration](configuration.md) - Customizing jj-fugitive behavior
- [Workflows](workflows.md) - Common development workflows with jj-fugitive