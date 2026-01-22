# jj-fugitive

A Neovim plugin that brings vim-fugitive-style version control integration for Jujutsu (jj).

## Project Overview

jj-fugitive provides seamless jj version control integration within Neovim, mimicking the workflow and feel of vim-fugitive but adapted for jj's unique features and commands. The plugin offers native jj log formatting, interactive status and diff views, comprehensive command completion, and robust ANSI color processing.

## Documentation

For detailed documentation, see:

- **[User Guide](doc/README.md)** - Complete feature list, keybindings, and usage examples
- **[Development Guide](doc/development.md)** - Setup, testing, and contribution instructions
- **[Interactive Commands](doc/interactive_commands.md)** - Technical reference for editor interception
- **[Test Documentation](tests/README.md)** - Test suite structure and running tests

### Additional Documentation

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
```

## Dependencies

- Neovim 0.8+ with Lua support
- jj CLI tool installed and accessible in PATH

## Development Quick Start

```bash
# Run comprehensive test suite
./tests/run_tests.sh

# Run linting and formatting
luacheck . && stylua --check .

# Auto-fix formatting
stylua .
```

For detailed development instructions, see [doc/development.md](doc/development.md).

## Version Control Workflow

This project uses Jujutsu (jj) for version control. Here are the common commands:

### Committing Changes

```bash
# Stage and describe your changes
jj describe -m "Your commit message"

# Create a new working copy for the next change
jj new

# Or combine both in one step
jj commit -m "Your commit message"
```

### Working with GitHub

```bash
# Add GitHub remote (first time setup)
jj git remote add origin https://github.com/username/jj-fugitive.nvim.git

# Create and set main bookmark (required for GitHub pushes)
jj bookmark create main          # Create main bookmark
jj bookmark set main             # Update main to current revision

# Fetch latest changes
jj git fetch

# Push to GitHub
jj git push --bookmark main      # Push specific bookmark
jj git push                      # Push all bookmarks

# Create a bookmark (branch) for feature work
jj bookmark create feature-name
jj git push --bookmark feature-name

# Pull Request workflow
jj bookmark create fix-issue-123
# ... make changes ...
jj describe -m "Fix issue #123: description"
jj git push --bookmark fix-issue-123
# Create PR on GitHub, then after merge:
jj git fetch
jj bookmark delete fix-issue-123
```

### Common Workflow

```bash
# Check status
jj status

# View history
jj log

# View history with more commits (jj log by default shows limited commits)
jj log -r ..         # Show all commits from root to current
jj log -r .. --limit 20   # Show last 20 commits from full history

# Move between revisions
jj next    # Move to child revision
jj prev    # Move to parent revision

# Edit a specific revision
jj edit <revision-id>

# Update main bookmark before pushing
jj bookmark set main    # Move main to current working copy
jj git push --bookmark main
```

## Important Notes & Best Practices

### Repository Management

- jj requires explicit bookmarks for GitHub integration
- Always update the `main` bookmark before pushing: `jj bookmark set main`
- Use `--bookmark` flag to push specific branches to GitHub
- The working copy becomes immutable after pushing, so jj creates a new commit on top

### jj Log Viewing

- **IMPORTANT**: `jj log` by default shows only recent commits
- **Always use `-r ..` to see more history**: `jj log -r ..` shows all commits from root
- **Combine with --limit**: `jj log -r .. --limit 50` for controlled output
- This is crucial for understanding the full repository history

### Development Workflow

- **Always run tests before committing**: `./tests/run_tests.sh`
- **Use descriptive commit messages**: Follow the project's commit style
- **Test from subdirectories**: Ensure repository detection works
- **Check CI status**: GitHub Actions must pass before merging

### Commit Message Format

```bash
jj describe -m "$(cat <<'EOF'
Brief description of changes

- Detailed point 1
- Detailed point 2
- Reference to issue if applicable

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### Testing Best Practices

- Run full test suite before pushing: `./tests/run_tests.sh`
- Test specific functionality after changes: `./tests/test_<feature>.lua`
- Use CI environment simulation: `export CI=true && ./tests/run_tests.sh`
- Add new tests for new features following existing patterns
- Ensure tests pass in both interactive and headless modes

### CI Integration

- GitHub Actions runs on every push to main and PR
- Tests run against Neovim stable and nightly
- All tests must pass for successful CI
- Linting and formatting are enforced
- Failed CI prevents merging
