# jj-fugitive.nvim

A Neovim plugin for [Jujutsu (jj)](https://github.com/martinvonz/jj) version control, inspired by vim-fugitive.

## Features

- **Log view as primary hub** — native jj log with ANSI colors, interactive commit actions
- **Bookmark management** — create, delete, move, track, push/fetch in a dedicated buffer
- **Rebase & stack management** — rebase from log view, passthrough for `jj arrange` and `jj parallelize`
- **Diff viewer** — unified diff with ANSI colors, side-by-side with Neovim's built-in diff mode
- **Describe & commit** — editor buffers for commit messages with `:w` to save
- **Smart completion** — tab completion for jj commands and subcommands
- **Browse** — open current file on GitHub/GitLab from Neovim

## Requirements

- Neovim 0.8+
- [Jujutsu](https://github.com/martinvonz/jj) installed and available in PATH

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{ "martintrojer/jj-fugitive" }
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use "martintrojer/jj-fugitive"
```

### Manual

```bash
git clone https://github.com/martintrojer/jj-fugitive ~/.local/share/nvim/site/pack/plugins/start/jj-fugitive
```

## Commands

| Command | Description |
|---------|-------------|
| `:J` | Open log view (primary hub) |
| `:J log` | Open log view with options (e.g. `:J log -r .. --limit 50`) |
| `:J diff [file]` | Show diff for file or working copy |
| `:J describe [rev]` | Edit commit description (default: `@`) |
| `:J commit` | Describe current change and create new one |
| `:J bookmark` | Open bookmark management buffer |
| `:J browse` / `:JBrowse` | Open current file on remote |
| `:J <any>` | Pass through to jj (e.g. `:J new`, `:J squash`, `:J arrange`) |

## Log View

The log view is the primary hub. Open with `:J` or `:J log`.

```
Commit actions:
  <CR>      Show commit details (jj show)
  d         Show diff for commit
  D         Describe (edit commit message)
  e         Edit at commit (jj edit)
  n         New change after commit (jj new)
  s         Squash into parent (jj squash)
  A         Abandon commit (jj abandon)

Bookmark:
  b         Create/move bookmark to commit under cursor

Rebase:
  grd       Rebase @ onto commit under cursor
  grs       Rebase source onto commit (prompts for source)
  grb       Rebase branch onto commit (prompts for branch)

Navigation:
  +/=       Show more commits
  R         Refresh
  q         Close
  g?        Help
```

## Bookmark Management

Open with `:J bookmark`.

```
  c         Create bookmark (prompts for name and revision)
  d         Delete bookmark under cursor
  m         Move bookmark to revision
  t         Track remote bookmark
  u         Untrack remote bookmark
  p         Push bookmark to remote
  f         Fetch from remote
  R         Refresh
  q         Close
  g?        Help
```

## Diff View

Open with `:J diff` or `:J diff <file>`.

```
  D         Side-by-side diff (opens in new tab with diffthis)
  o         Open file in editor
  [c / ]c   Navigate changes
  q         Close
  g?        Help
```

## Describe & Commit

`:J describe [rev]` opens an editor buffer for the commit message. `:J commit` does the same but also creates a new change after saving. Lines starting with `#` are ignored. Save with `:w`.

## License

MIT
