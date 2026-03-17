# jj-fugitive

A Neovim plugin that brings vim-fugitive-style version control integration for Jujutsu (jj).

## Project Overview

jj-fugitive provides seamless jj version control integration within Neovim, mimicking the workflow and feel of vim-fugitive but adapted for jj's unique features and commands. The plugin offers native jj log formatting, interactive status and diff views, comprehensive command completion, and robust ANSI color processing.

## Documentation

- **[User Guide](doc/README.md)** - Complete feature list, keybindings, and usage examples
- **[Development Guide](doc/development.md)** - Setup, testing, and contribution instructions
- **[Interactive Commands](doc/interactive_commands.md)** - Technical reference for editor interception
- **[Test Documentation](tests/README.md)** - Test suite structure and running tests
- **[Enhanced Diff](doc/enhanced-diff.md)** - Detailed diff improvements
- **[:J Command](doc/j-command.md)** - Universal jj command with multi-level smart completion
- **[Status Buffer](doc/jstatus.md)** - Interactive status buffer details
- **[Diff Viewer](doc/jdiff.md)** - Enhanced diff viewer details

## Quick Reference

```vim
:J                      " Show interactive status buffer
:J status               " Show interactive status buffer
:J log                  " Show native jj log view
:J diff [file]          " Show diff for file
:JBrowse                " Open remote URL in browser
:JHelp                  " Show available commands
```

## Architecture

```
lua/jj-fugitive/
├── init.lua          # Main plugin entry point and :J command dispatcher
├── status.lua        # Interactive status view with file navigation
├── log.lua           # Native jj log view with authentic formatting
├── diff.lua          # Enhanced diff view with ANSI color support
├── completion.lua    # Command completion and help system
├── browse.lua        # Remote URL construction for :JBrowse
├── ui.lua            # Shared UI utilities, patterns, and buffer helpers
└── ansi.lua          # Unified ANSI color processing and buffer creation

plugin/jj-fugitive.lua  # Plugin entry point, registers :J, :JHelp, :JBrowse commands
```

## Dependencies

- Neovim 0.8+ with Lua support
- jj CLI tool installed and accessible in PATH

## Development

```bash
# Run comprehensive test suite
./tests/run_tests.sh

# Run linting and formatting checks
luacheck . && stylua --check .

# Auto-fix formatting
stylua .
```

- Always run tests before committing: `./tests/run_tests.sh`
- CI runs luacheck, stylua, and tests against Neovim stable + nightly
- Test specific functionality: `./tests/test_<feature>.lua`

## Version Control

This project uses Jujutsu (jj) for version control.

```bash
# Common workflow
jj status                        # Check status
jj log                           # View recent history
jj log -r .. --limit 20         # View more history (jj log defaults to few commits)
jj describe -m "message"         # Describe current change
jj new                           # Start new change
jj commit -m "message"           # Describe + new in one step

# Pushing to GitHub
jj bookmark set main             # Update main bookmark to current revision
jj git push --bookmark main      # Push to remote
```

### Commit Message Format

```
type: brief description

- Detail 1
- Detail 2

Co-Authored-By: Claude <noreply@anthropic.com>
```

Common types: `fix`, `feat`, `docs`, `refactor`, `test`, `chore`
