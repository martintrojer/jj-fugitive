# jj-fugitive.nvim

A Neovim plugin for [Jujutsu (jj)](https://github.com/martinvonz/jj) version control, inspired by vim-fugitive.

## Features

- **Log view as primary hub** — native jj log with ANSI colors, interactive commit actions
- **Bookmark management** — create, delete, move, track, push/fetch in a dedicated buffer
- **Rebase & stack management** — rebase from log view, passthrough for `jj arrange` and `jj parallelize`
- **Diff viewer** — unified diff with ANSI colors, side-by-side with Neovim's built-in diff mode
- **Status view** — changed files with inline diff toggle (`=`), open, diff, restore
- **Describe & commit** — editor buffers for commit messages with `:w` to save
- **Annotate/blame** — scroll-locked per-line attribution with `<CR>` to show commit
- **TUI integration** — `arrange`, `split`, `diffedit`, `resolve` run in `:terminal`
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

## Configuration

```lua
-- Default settings (no setup call needed)
require("jj-fugitive").setup({
  default_command = "log",     -- "log" or "status": what :J opens
  open_mode = "split",         -- "split" or "tab": how views open
  ignore_immutable = false,    -- allow rewriting immutable commits
})
```

## Commands

| Command | Description |
|---------|-------------|
| `:J` | Open log view (primary hub) |
| `:J log` | Open log view with options (e.g. `:J log -r .. --limit 50`) |
| `:J status` | Show changed files with actions |
| `:J diff [file]` | Show diff for file or working copy |
| `:J describe [rev]` | Edit commit description (default: `@`) |
| `:J commit` | Describe current change and create new one |
| `:J bookmark` | Open bookmark management buffer |
| `:J annotate [file]` | Blame/annotate current file (also `:J blame`) |
| `:J browse` / `:JBrowse` | Open current file on remote |
| `:J <any>` | Pass through to jj (e.g. `:J new`, `:J squash`, `:J arrange`) |

## Log View

The log view is the primary hub. Open with `:J` or `:J log`.

```
Commit actions:
  <CR>      Show commit details (jj show)
  d         Show diff for commit
  cc        Describe (edit commit message)
  e         Edit at commit (jj edit)
  n         New change after commit (jj new)
  S         Squash into parent (jj squash)
  A         Abandon commit (jj abandon)

Bookmark:
  b         Create/move bookmark to commit under cursor

Rebase:
  grd       Rebase @/@- onto commit under cursor (auto-detects empty @)
  grs       Rebase source onto commit (prompts for source)
  grb       Rebase branch onto commit (prompts for branch)

Navigation:
  gs        Switch to status view
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

## Status View

Open with `:J status` or `:J st`. Shows changed files in the working copy.

```
  <CR>/o    Open file
  =         Toggle inline diff (fugitive-style)
  d         Show diff for file
  D         Side-by-side diff
  x         Restore file from parent (@-)
  gl        Switch to log view
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

## Annotate / Blame

Open with `:J annotate` or `:J blame`. Shows per-line attribution in a
scroll-locked split alongside the source file.

```
  <CR>      Show commit for this line
  q         Close annotation
  g?        Help
```

## Describe & Commit

`:J describe [rev]` opens an editor buffer for the commit message. `:J commit` does the same but also creates a new change after saving. Lines starting with `#` are ignored. Save with `:w`.

## Changes from v1

v2 is a complete rewrite focused on simplicity and core jj workflows.

**New:**
- Dedicated bookmark buffer with create, delete, move, track, push/fetch
- Rebase keybindings from log view (`grd`, `grs`, `grb`)
- TUI commands (`arrange`, `split`, `diffedit`, `resolve`) run in `:terminal`
- Annotate/blame view with scroll-locked split
- Status view with inline diff toggle (`=`)
- Uses jj change IDs (stable across rewrites) instead of commit hashes
- Configurable default command and open mode (`split` or `tab`)
- `setup()` function for user configuration

**Changed:**
- `:J` opens log by default (was status in v1)
- Describe key in log is `cc` (was `D`)
- Simpler completion (commands + subcommands, no deep flag parsing)
- Single `run_jj()` API (no `run_jj_command_from_module` indirection)
- Repo detection via `vim.fs.find` (no manual cache)

**Removed:**
- Interactive command stubs (split/diffedit/resolve editor interception)
- Buffer-reuse state machine (`update_current`/`previous_view`)
- Format selector in diff view
- Emoji indicators in log (jj's native symbols are used)
- Deep flag completion and caching

## License

MIT
