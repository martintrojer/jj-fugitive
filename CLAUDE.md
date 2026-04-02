# jj-fugitive

A Neovim plugin for Jujutsu (jj) version control, inspired by vim-fugitive.

## Quick Reference

```vim
:J                      " Show log view (primary hub)
:J log                  " Show log view with options
:J status               " Show changed files with actions
:J diff [file]          " Show diff for file or working copy
:J annotate [file]      " Blame/annotate (also :J blame)
:J describe [rev]       " Edit commit description
:J commit               " Commit (describe + new)
:J bookmark             " Bookmark management
:J push [args]          " Push to remote (jj git push)
:J fetch [args]         " Fetch from remote (jj git fetch)
:JBrowse                " Open remote URL in browser
```

## Architecture

```
lua/jj-fugitive/
├── init.lua          # :J dispatcher, repo detection, run_jj() command runner
├── log.lua           # Log view: display, keybindings, commit actions
├── status.lua        # Status view: changed files with file actions
├── diff.lua          # Diff view: unified + side-by-side
├── review.lua        # Shared AI-ready review buffer and comment capture
├── annotate.lua      # Blame/annotate with scroll-locked split
├── describe.lua      # Describe/commit editor buffers
├── bookmark.lua      # Bookmark management buffer
├── completion.lua    # Command completion from jj --help
├── browse.lua        # Remote URL construction for :JBrowse
├── ansi.lua          # ANSI color parsing and buffer creation
└── ui.lua            # Shared utilities: buffers, keymaps, popups

plugin/jj-fugitive.lua  # Registers :J, :JBrowse commands
```

## Design Decisions

### Synchronous `run_jj` via `vim.system():wait()`

All jj commands run synchronously. `vim.system():wait()` still processes Neovim
events (redraws, etc.) so the UI is not fully frozen. A "jj: running..." message
appears after 200ms for slow commands.

Do NOT automatically retry failed commands. Retrying mutations (rebase, squash)
on already-modified state causes cascading damage. Let the user retry manually.

Do NOT convert to async callbacks. The synchronous flow keeps the code simple —
every caller gets a return value and acts on it linearly. Async would introduce
race conditions, callback-scattered error handling, ordering bugs (refresh before
mutation completes), and stale UI state between dispatch and callback.

## Dependencies

- Neovim 0.10+ with Lua support
- jj CLI tool in PATH

## Development

```bash
luacheck lua/jj-fugitive/ plugin/ && stylua --check .
```

## Version Control

This project uses Jujutsu (jj).

```bash
jj describe -m "message"         # Describe current change
jj new                           # Start new change
jj bookmark set main && jj git push --bookmark main  # Push
```

### Commit Message Format

```
type: brief description

Co-Authored-By: Claude <noreply@anthropic.com>
```

Common types: `fix`, `feat`, `docs`, `refactor`, `test`, `chore`
