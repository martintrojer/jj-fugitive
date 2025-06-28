# jj-fugitive

A Neovim plugin that brings vim-fugitive-style version control integration for Jujutsu (jj).

## Project Overview

jj-fugitive aims to provide seamless jj version control integration within Neovim, mimicking the workflow and feel of vim-fugitive but adapted for jj's unique features and commands.

## Key Features to Implement

### Core Commands
- `:Jj` - Main jj status interface (similar to `:Git` in vim-fugitive)
- `:JjLog` - Show revision history with customizable templates
- `:JjDiff` - Compare file contents between revisions
- `:JjStatus` - High-level repository status
- `:JjCommit` - Create commits with interactive message editing
- `:JjNew` - Create new changes

### Navigation Commands
- `:JjNext` - Move to next child revision
- `:JjPrev` - Move to parent revision
- `:JjEdit` - Set specific revision as working copy

### Bookmark Management
- `:JjBookmark` - List, create, and manage bookmarks
- Integration with branch-like workflows

### Git Integration
- `:JjGitFetch` - Fetch from Git remotes
- `:JjGitPush` - Push to Git remotes

## Development Guidelines

### Architecture
- Written in Lua for Neovim
- Follow vim-fugitive's command patterns and UI principles
- Minimize keystrokes for common operations
- Provide contextual, in-editor commands

### User Experience Principles
- Maintain vim-fugitive's familiar keybindings where applicable
- Adapt commands to jj's revision-centric model
- Provide interactive staging/unstaging capabilities
- Implement side-by-side diff views

### Code Organization
- Modular command structure
- Separate modules for different jj operations
- Consistent error handling and user feedback
- Proper integration with Neovim's buffer and window management

## Testing Strategy
- Unit tests for core jj command wrappers
- Integration tests for UI components
- Manual testing with various jj repository states

## Dependencies
- Neovim with Lua support
- jj CLI tool installed and accessible in PATH

## Development Commands

### Testing
```bash
# Install plenary.nvim for testing
git clone https://github.com/nvim-lua/plenary.nvim /tmp/plenary.nvim

# Run tests
export PLENARY_DIR=/tmp/plenary.nvim
nvim --headless --noplugin -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"
```

### Linting
```bash
# Install luacheck
brew install luacheck  # or luarocks install luacheck

# Run linting
luacheck .
```

### Formatting
```bash
# Install stylua
brew install stylua  # or cargo install stylua

# Format code
stylua .

# Check formatting
stylua --check .
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

### Important Notes
- jj requires explicit bookmarks for GitHub integration
- Always update the `main` bookmark before pushing: `jj bookmark set main`
- Use `--bookmark` flag to push specific branches to GitHub
- The working copy becomes immutable after pushing, so jj creates a new commit on top