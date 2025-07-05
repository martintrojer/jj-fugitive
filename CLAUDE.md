# jj-fugitive

A Neovim plugin that brings vim-fugitive-style version control integration for Jujutsu (jj).

## Project Overview

jj-fugitive provides seamless jj version control integration within Neovim, mimicking the workflow and feel of vim-fugitive but adapted for jj's unique features and commands. The plugin offers native jj log formatting, interactive status and diff views, comprehensive command completion, and robust ANSI color processing.

## Current Implementation Status

### ✅ Implemented Features

#### Core Commands
- `:J` - Main jj interface with subcommands (✅ **COMPLETE**)
- `:J status` - Interactive status view with file navigation (✅ **COMPLETE**)
- `:J log` - Native jj log view with authentic formatting and symbols (✅ **COMPLETE**)
- `:J diff <file>` - Enhanced diff view with ANSI color support (✅ **COMPLETE**)
- `:JHelp` - Inline help system with command documentation (✅ **COMPLETE**)

#### Advanced Features
- **Native jj Integration**: Preserves authentic jj log formatting (@, ◆, ○, │, ~)
- **ANSI Color Processing**: Unified color handling across all views
- **Interactive Navigation**: Enter key functionality in log and status views
- **Expandable Log View**: Expand log view to show more commits with `=` or `+` keys
- **Repository Detection**: Works from any subdirectory within jj repo
- **Command Completion**: Full tab completion for jj commands and flags
- **Error Handling**: Robust error detection and user feedback

#### Architecture
- **6 Core Modules**: ansi.lua, completion.lua, diff.lua, init.lua, log.lua, status.lua
- **49+ Functions**: Comprehensive functionality across all modules
- **22 Test Files**: Extensive test coverage with intelligent discovery

### 🚧 Future Features (Not Yet Implemented)

#### Navigation Commands
- `:JNext` - Move to next child revision
- `:JPrev` - Move to parent revision
- `:JEdit` - Set specific revision as working copy

#### Bookmark Management
- `:JBookmark` - List, create, and manage bookmarks
- Integration with branch-like workflows

#### Git Integration
- `:JGitFetch` - Fetch from Git remotes
- `:JGitPush` - Push to Git remotes

## Current Architecture

### Module Structure
```
lua/jj-fugitive/
├── init.lua          # Main plugin entry point and :J command dispatcher
├── status.lua         # Interactive status view with file navigation
├── log.lua           # Native jj log view with authentic formatting
├── diff.lua          # Enhanced diff view with ANSI color support
├── completion.lua    # Command completion and help system  
└── ansi.lua          # Unified ANSI color processing and buffer creation
```

### Key Design Principles
- **Native jj Integration**: Preserves authentic jj output formatting and colors
- **Idiomatic jj Workflow**: Designed around jj's change-centric model (no staging area)
- **Modular Architecture**: 6 focused modules with clear responsibilities
- **ANSI Color Processing**: Unified system for color parsing and buffer highlighting
- **Repository Detection**: Automatic jj repository root detection from any subdirectory
- **Error Handling**: Comprehensive error detection with user-friendly messages
- **Selective vim-fugitive Compatibility**: Adapts vim-fugitive patterns that make sense for jj

### User Experience Features
- **Interactive Navigation**: Enter key functionality in log and status views
- **Contextual Commands**: Commands adapt based on cursor position and file type
- **Tab Completion**: Full completion for jj commands, flags, and file paths
- **Visual Feedback**: Progress indicators and status messages
- **Keyboard Shortcuts**: Intuitive keybindings for common operations

### jj vs Git Workflow Differences
- **No Staging Area**: jj automatically tracks all files, no manual staging needed
- **Working Copy as Commit**: Your working directory is always a commit
- **Change-Centric**: Focus on "changes" rather than individual commits
- **Automatic Rebasing**: Descendants automatically rebase when you modify commits
- **No File Tracking Commands**: Files are auto-tracked, removed Git-style `-`, `s`, `u` commands

## Quick Start Usage

### Basic Commands
```vim
:J status          \" Interactive status view
:J log             \" Native jj log with authentic formatting  
:J diff <file>     \" Enhanced diff view for specific file
:JHelp             \" Show available commands and help
```

### Interactive Features
- **Status View**: Press `Enter` on file to see diff, `l` for log view
- **Log View**: Press `Enter` on commit to see details and diff, `=` or `+` to expand view
- **Tab Completion**: Use `<Tab>` for command and file completion
- **Repository Detection**: Works from any subdirectory in jj repo

### Example Workflow
```vim
:J status          \" See what files have changed
\" Navigate to file, press Enter to see diff
:J log --limit 10  \" View recent commits with native jj formatting
\" Navigate to commit, press Enter to see details
\" Press = or + to expand log view and see more commits
```

## Testing Strategy

### Comprehensive Test Suite (23 Tests)
- **Unit Tests**: Core jj command wrappers and module loading
- **Integration Tests**: Cross-component functionality and ANSI processing
- **End-to-End Tests**: Complete user workflow simulation
- **Regression Tests**: Prevention of known issues
- **CI Tests**: Automated testing with GitHub Actions

### Test Categories
- **Core Functionality**: Status, diff, log, completion (4 tests)
- **Native Integration**: jj log format, ANSI processing, repository detection (3 tests)
- **Advanced Features**: Interactive navigation, keybindings, cursor positioning (4 tests)
- **Color & Format**: ANSI color rendering, format consistency (5 tests)
- **User Experience**: End-to-end workflows, vim-fugitive compatibility (4 tests)
- **Documentation & Quality**: Documentation completeness (2 tests)

### Intelligent Test Discovery
- Automatic discovery of all `test_*.lua` files
- Parallel execution with detailed reporting
- CI environment detection for timing-sensitive tests
- Demo file support (non-critical)
- Executable management (automatic chmod +x)

## Dependencies
- Neovim with Lua support
- jj CLI tool installed and accessible in PATH

## Development Commands

### Prerequisites
```bash
# Required tools
brew install luacheck     # Lua linting
brew install stylua       # Lua formatting
brew install jj           # Jujutsu CLI (if not already installed)

# Or install via package managers
# Ubuntu/Debian: apt install luacheck stylua
# Arch: pacman -S luacheck stylua-bin
```

### Testing
```bash
# Run comprehensive test suite (RECOMMENDED)
# Includes: linting, formatting, all 22 functional tests
./tests/run_tests.sh

# Run only functional tests (skip linting/formatting)
# Useful for CI or when linting/formatting are handled separately
./tests/run_tests.sh --tests-only

# Show help with all options
./tests/run_tests.sh --help

# Run specific test categories
./tests/test_status_functionality.lua      # Status view tests
./tests/test_log_functionality.lua         # Log view tests  
./tests/test_native_log_view.lua           # Native jj format tests
./tests/test_commit_extraction.lua         # ANSI processing tests
./tests/test_repository_detection.lua      # Subdirectory detection

# Run all tests matching pattern
./tests/test_log*.lua                      # All log-related tests
./tests/test_*functionality.lua           # All functionality tests

# Manual/interactive testing
nvim tests/manual_test.lua
./tests/demo_log_view.lua                  # Interactive log demo
./tests/demo_enhanced_diff.lua             # Interactive diff demo
```

### Linting & Formatting
```bash
# Check linting (included in test runner)
luacheck .

# Check formatting (included in test runner)
stylua --check .

# Auto-fix formatting
stylua .

# Pre-commit workflow (recommended)
luacheck . && stylua --check . && ./tests/run_tests.sh
```

### Continuous Integration
```bash
# Simulate CI environment locally
export CI=true
./tests/run_tests.sh

# GitHub Actions automatically runs:
# - luacheck (lint job)
# - stylua --check (format job) 
# - ./tests/run_tests.sh (test job)
# On push to main and all pull requests
```

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

# Move between revisions
jj next    # Move to child revision
jj prev    # Move to parent revision

# Edit a specific revision
jj edit <revision-id>

# Update main bookmark before pushing
jj bookmark set main    # Move main to current working copy
jj git push --bookmark main
```

### Important Notes & Best Practices

#### Repository Management
- jj requires explicit bookmarks for GitHub integration
- Always update the `main` bookmark before pushing: `jj bookmark set main`
- Use `--bookmark` flag to push specific branches to GitHub
- The working copy becomes immutable after pushing, so jj creates a new commit on top

#### Development Workflow
- **Always run tests before committing**: `./tests/run_tests.sh`
- **Use descriptive commit messages**: Follow the project's commit style
- **Test from subdirectories**: Ensure repository detection works
- **Check CI status**: GitHub Actions must pass before merging

#### Commit Message Format
```bash
jj describe -m "$(cat <<'EOF'
Brief description of changes

- Detailed point 1
- Detailed point 2
- Reference to issue if applicable

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

#### Testing Best Practices
- Run full test suite before pushing: `./tests/run_tests.sh`
- Test specific functionality after changes: `./tests/test_<feature>.lua`
- Use CI environment simulation: `export CI=true && ./tests/run_tests.sh`
- Add new tests for new features following existing patterns
- Ensure tests pass in both interactive and headless modes

#### CI Integration
- GitHub Actions runs on every push to main and PR
- Tests run against Neovim stable and nightly
- All 22 tests must pass for successful CI
- Linting and formatting are enforced
- Failed CI prevents merging