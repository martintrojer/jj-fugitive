# Jujutsu Interactive Commands that Need Editor Interception

This document lists all jj commands that open an editor or are interactive by default and need to be intercepted in the jj-fugitive plugin to open the editor in a new Neovim buffer instead of hanging.

## Primary Interactive Commands (Always Interactive)

### 1. `describe` (alias: `desc`)
- **Default behavior**: Opens `$EDITOR` (or `pico`/`Notepad`) to edit change description
- **Bypass options**: `-m/--message`, `--stdin`, `--no-edit`
- **Interactive unless**: One of the bypass options is used
- **Command**: `jj describe [revsets]`

### 2. `commit`
- **Default behavior**: Opens editor for commit message (like `describe`)
- **Bypass options**: `-m/--message`
- **Additional interactive modes**: `-i/--interactive`, `--tool` (diff editor)
- **Command**: `jj commit [filesets]`

### 3. `split`
- **Default behavior**: Opens diff editor to select changes, then editor for description
- **Interactive modes**: Always interactive by default (unless `--message` used for description)
- **Command**: `jj split [filesets]`

## Conditionally Interactive Commands

### 4. `diffedit`
- **Default behavior**: Always opens diff editor
- **Tool selection**: `--tool` option to specify diff editor
- **Command**: `jj diffedit`

### 5. `resolve`
- **Default behavior**: Opens external merge tool for each conflict
- **Tool selection**: `--tool` option to specify merge tool
- **Non-interactive mode**: `--list` to just list conflicts
- **Command**: `jj resolve [filesets]`

### 6. `commit --interactive` / `commit --tool`
- **Interactive mode**: When `-i/--interactive` or `--tool` flags are used
- **Behavior**: Opens diff editor to select changes
- **Command**: `jj commit -i` or `jj commit --tool <tool>`

### 7. `split --interactive` / `split --tool`
- **Interactive mode**: When `-i/--interactive` or `--tool` flags are used (default if no filesets)
- **Behavior**: Opens diff editor to select changes
- **Command**: `jj split -i` or `jj split --tool <tool>`

## Implementation Strategy

### High Priority (Always Interactive)
These commands should be intercepted to prevent hanging:
1. `describe` (without `-m`, `--stdin`, or `--no-edit`)
2. `commit` (without `-m`)
3. `split` (always opens diff editor)

### Medium Priority (Conditionally Interactive)
These commands should be intercepted when specific flags are used:
4. `diffedit` (always interactive)
5. `resolve` (without `--list`)
6. `commit -i` or `commit --tool`
7. `split -i` or `split --tool`

### Detection Logic
```lua
-- Detect if command will be interactive
local function is_interactive_command(cmd_parts)
    local command = cmd_parts[1]
    
    -- Always interactive commands
    if command == "describe" or command == "desc" then
        return not (has_flag(cmd_parts, "-m") or has_flag(cmd_parts, "--message") or 
                   has_flag(cmd_parts, "--stdin") or has_flag(cmd_parts, "--no-edit"))
    end
    
    if command == "commit" then
        return not has_flag(cmd_parts, "-m") and not has_flag(cmd_parts, "--message")
    end
    
    if command == "split" then
        return true  -- Always opens diff editor
    end
    
    if command == "diffedit" then
        return true  -- Always opens diff editor
    end
    
    if command == "resolve" then
        return not has_flag(cmd_parts, "--list")
    end
    
    return false
end
```

### Editor Interception Strategy
For interactive commands, the plugin should:
1. Create a new buffer with appropriate content
2. Set up the buffer for editing (commit message, diff content, etc.)
3. Provide save/commit functionality
4. Handle the jj command execution after user completes editing

### Diff Editor vs Text Editor
- **Text Editor**: `describe`, `commit` (for commit messages)
- **Diff Editor**: `diffedit`, `split`, `commit -i`, `resolve`
- **Mixed**: `split` uses diff editor for changes, then text editor for description