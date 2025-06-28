# JDiff - Enhanced Diff Viewer

The `:JDiff` command provides an enhanced diff viewing experience with both unified and side-by-side formats, seamlessly integrated with the jj-fugitive workflow.

## Overview

`:JDiff` offers advanced diff visualization features:

- **Unified diff format** - Traditional diff with syntax highlighting
- **Side-by-side diff format** - Compare original and current versions
- **File-specific diffs** - View changes for individual files
- **Interactive toggling** - Switch between formats on the fly
- **Integration with status buffer** - Seamless workflow from `:JStatus`

## Usage

### Basic Commands

```vim
:JDiff              " Show all changes in unified format
:JDiff filename     " Show diff for specific file
```

### From Status Buffer

In the `:JStatus` buffer, press `dd` on any file to open its diff in the enhanced viewer.

## Diff Formats

### Unified Format (Default)

The unified format shows changes in a traditional diff style:

```diff
diff --git a/src/main.rs b/src/main.rs
index abc123..def456 100644
--- a/src/main.rs
+++ b/src/main.rs
@@ -10,7 +10,7 @@ fn main() {
     let mut x = 0;
-    x = x + 1;
+    x += 1;
     println!("Value: {}", x);
```

**Features:**
- Syntax highlighting for the target file type
- Standard diff format that's familiar to most developers
- Compact view showing context and changes together
- Line numbers and change indicators (+/-) 

### Side-by-Side Format

The side-by-side format shows original and current versions in separate panes:

```
┌─ Original (before) ────────┬─ Current (after) ──────────┐
│ fn main() {                │ fn main() {                │
│     let mut x = 0;         │     let mut x = 0;         │
│     x = x + 1;             │     x += 1;                │
│     println!("Value: {}", x);  │     println!("Value: {}", x);  │
│ }                          │ }                          │
└────────────────────────────┴────────────────────────────┘
```

**Features:**
- Full syntax highlighting for both versions
- Clear visual separation of before/after
- Better for understanding larger changes
- Native Neovim diff mode with synchronized scrolling

## Keybindings

### In Any Diff Buffer

| Key | Action |
|-----|--------|
| `s` | Toggle between unified and side-by-side formats |
| `q` | Close the diff buffer |

### In Side-by-Side Mode

| Key | Action |
|-----|--------|
| `]c` | Jump to next change (Neovim built-in) |
| `[c` | Jump to previous change (Neovim built-in) |
| `do` | Obtain change from other buffer (Neovim built-in) |
| `dp` | Put change to other buffer (Neovim built-in) |

## Buffer Types and Options

### Unified Diff Buffer

- **Buffer type**: `nofile` - Temporary buffer, not associated with a file
- **Filetype**: `diff` - Enables diff syntax highlighting
- **Modifiable**: `false` - Read-only buffer
- **Buffer name**: `jj-diff: filename` - Descriptive name for buffer identification

### Side-by-Side Buffers

- **Left buffer**: Shows original content from parent commit (`@-`)
- **Right buffer**: Shows current working copy content
- **Both buffers**: 
  - Proper filetype detection based on file extension
  - Read-only to prevent accidental modifications
  - Diff mode enabled for synchronized scrolling

## Integration Features

### Status Buffer Integration

The diff viewer integrates seamlessly with `:JStatus`:

1. Open status buffer: `:JStatus`
2. Navigate to any file with changes
3. Press `dd` to open the enhanced diff viewer
4. Toggle between formats as needed
5. Close diff and return to status buffer

### Conflict Resolution

While `:JDiff` is primarily for viewing changes, it provides a foundation for future conflict resolution features:

- Side-by-side view makes conflicts easier to understand
- Built-in diff commands (`do`, `dp`) work in side-by-side mode
- Future versions may add jj-specific conflict resolution

## Advanced Usage

### Multiple Files

View diffs for multiple files in sequence:

```vim
:JDiff file1.rs     " View first file
:q                  " Close diff
:JDiff file2.rs     " View second file
```

### From Command Line

Integrate with external tools:

```bash
# View diff and then open Neovim
jj diff > /tmp/changes.diff
nvim /tmp/changes.diff

# Or directly in Neovim
nvim -c "JDiff src/main.rs"
```

## File Type Support

The diff viewer supports syntax highlighting for all file types that Neovim recognizes:

- **Programming languages**: Rust, Python, JavaScript, Go, etc.
- **Markup languages**: Markdown, HTML, XML, etc.
- **Configuration files**: JSON, YAML, TOML, etc.
- **Scripts**: Shell, PowerShell, etc.

File type detection is automatic based on file extension.

## Performance Considerations

### Large Files

For large files, the diff viewer:
- Uses efficient buffer management
- Loads content on-demand
- Provides responsive scrolling in both formats

### Memory Usage

- Unified format uses a single buffer
- Side-by-side format uses two buffers but shares content efficiently
- Buffers are automatically cleaned up when closed

## Troubleshooting

### Empty Diff Buffer

If the diff buffer appears empty:

1. **Check file status**: Ensure the file has actual changes
2. **Verify jj operation**: Run `jj diff filename` in terminal
3. **File permissions**: Ensure the file is readable

### Syntax Highlighting Issues

If syntax highlighting doesn't work:

1. **Check filetype**: `:set filetype?` in the diff buffer
2. **File extension**: Ensure the file has a recognized extension
3. **Neovim configuration**: Verify syntax highlighting is enabled

### Side-by-Side Mode Problems

If side-by-side mode doesn't work correctly:

1. **Terminal size**: Ensure terminal is wide enough for two panes
2. **Diff mode**: Check if `:set diff?` shows `diff` is enabled
3. **Buffer creation**: Verify both buffers are created successfully

## Examples

### Basic Workflow

```vim
" View all changes
:JDiff

" Switch to side-by-side view
s

" Close and view specific file
q
:JDiff src/main.rs

" Return to unified view
s
```

### Integration with Status

```vim
" Open status buffer
:JStatus

" Navigate to modified file (e.g., src/lib.rs)
/src/lib.rs

" View diff for that file
dd

" Toggle to side-by-side
s

" Close diff and return to status
q
```

### Multiple File Review

```vim
" Start with status to see all changes
:JStatus

" Review each file:
" 1. Position cursor on file
" 2. Press 'dd' to view diff
" 3. Press 's' to toggle format if needed
" 4. Press 'q' to return to status
" 5. Repeat for next file
```

## Future Enhancements

Planned improvements for `:JDiff`:

- **Three-way diff support** for merge conflicts
- **Revision comparison** (e.g., compare any two revisions)
- **Inline edit mode** for quick fixes
- **Export functionality** to save diffs to files
- **Custom diff algorithms** (patience, histogram, etc.)

## See Also

- [JStatus Documentation](jstatus.md) - Interactive status buffer that integrates with JDiff
- [J Command Documentation](j-command.md) - Universal jj command interface
- [Development Guide](development.md) - Information for plugin developers