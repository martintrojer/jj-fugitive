# Enhanced Diff View

The jj-fugitive plugin provides an enhanced diff viewing experience with improved visual clarity, color coding, and user-friendly formatting.

## Visual Enhancements

### Icons and Indicators

The enhanced diff view uses visual emoji icons to make different diff elements immediately recognizable:

| Icon | Element | Description |
|------|---------|-------------|
| 📄 | File Header | Shows which file is being diffed |
| 🔄 | Change Description | Indicates working copy vs parent comparison |
| 📁 | Git Diff Header | Standard git diff header line |
| 📍 | Hunk Location | Marks location of change hunks (@@...@@) |
| ❌ | Removed Lines | Lines that were deleted (red background) |
| ✅ | Added Lines | Lines that were added (green background) |
| ⬅️ | Old File Marker | Points to original file version |
| ➡️ | New File Marker | Points to current file version |
| 🔗 | Index Information | Git index/blob information |

### Color Scheme

The enhanced diff view uses a carefully designed color scheme for optimal readability:

- **File Headers**: Cyan with bold text
- **Change Descriptions**: Gray with italic text  
- **Diff Headers**: Yellow with bold text
- **Hunk Locations**: Magenta with bold text
- **Removed Lines**: Light red text with dark red background
- **Added Lines**: Light green text with dark green background
- **Context Lines**: Light gray text
- **Separators**: Gray horizontal lines

## Usage

### Opening Enhanced Diff View

```vim
:J diff                    " Show diff for current buffer file
:J diff filename.txt       " Show diff for specific file
```

From the status buffer (`:J`), press `dd` on any file to open its enhanced diff.

### Navigation and Controls

| Key | Action |
|-----|--------|
| `q` | Close diff view |
| `s` | Switch to side-by-side view |
| `r` | Refresh diff |
| `o` | Open file in editor |
| `?` | Show help |

### Example Output

```diff
📄 File: src/main.rs
🔄 Changes in working copy vs parent (@-)
────────────────────────────────────────────────────────────

📁 diff --git a/src/main.rs b/src/main.rs
🔗 index abc123..def456 100644
⬅️  --- a/src/main.rs
➡️  +++ b/src/main.rs

📍 @@ -10,7 +10,7 @@ fn main() {
     let mut x = 0;
❌ x = x + 1;
✅ x += 1;
     println!("Value: {}", x);
```

## Benefits

### Improved Readability

- **Clear Visual Hierarchy**: Icons and colors create a clear visual hierarchy
- **Reduced Cognitive Load**: Emoji icons are faster to parse than text symbols
- **Better Scanning**: Color coding allows quick identification of change types
- **Enhanced Context**: File headers provide immediate context

### Better User Experience

- **Consistent Interface**: Unified look and feel across all diff views
- **Accessible Design**: Colors work well in both light and dark themes
- **Informative Headers**: Clear description of what's being compared
- **Visual Separation**: Proper spacing and separators improve organization

## Technical Implementation

### Custom Syntax Highlighting

The enhanced diff view uses custom Neovim syntax highlighting groups:

- `JjDiffHeader` - File and change headers
- `JjDiffSubHeader` - Secondary information
- `JjDiffSeparator` - Visual separators
- `JjDiffFileHeader` - Git diff headers
- `JjDiffHunk` - Hunk location markers
- `JjDiffRemoved` - Removed lines with background
- `JjDiffAdded` - Added lines with background
- `JjDiffContext` - Context lines

### Content Processing

The diff content is processed to:

1. Add emoji icons to different line types
2. Insert informative headers
3. Add visual separators
4. Format hunk markers for prominence
5. Apply consistent spacing

## Compatibility

The enhanced diff view:

- Works in both terminal and GUI Neovim
- Supports both light and dark color schemes
- Falls back gracefully if emoji support is limited
- Maintains all standard diff functionality
- Integrates seamlessly with existing workflows

## Testing

Run the enhanced diff demo to see the features in action:

```bash
./tests/demo_enhanced_diff.lua
```

This will create a test scenario and showcase all the visual enhancements.

## See Also

- [Diff Viewer Documentation](jdiff.md) - Complete diff functionality guide
- [Status Buffer Documentation](jstatus.md) - Interactive status buffer
- [J Command Documentation](j-command.md) - Universal command interface