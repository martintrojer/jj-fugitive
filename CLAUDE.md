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
Run tests: (TBD - determine testing framework)
Lint: (TBD - determine linting approach for Lua)