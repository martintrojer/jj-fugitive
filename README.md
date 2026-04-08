# jj-fugitive.nvim

A Neovim plugin for [Jujutsu (jj)](https://github.com/martinvonz/jj) version control, inspired by vim-fugitive.

## Features

- **Log view as primary hub** — native jj log with ANSI colors, interactive commit actions
- **Bookmark management** — create, delete, move, track, push/fetch in a dedicated buffer
- **Rebase & squash** — full rebase and squash keybindings from log view with symmetric lowercase/uppercase convention
- **Diff viewer** — unified diff with ANSI colors, side-by-side with Neovim's built-in diff mode, buffer reuse
- **Status view** — changed files with inline diff toggle (`=`), open, split, diff, restore, describe, split
- **Describe & commit** — editor buffers for commit messages with `:w` to save
- **Annotate/blame** — scroll-locked per-line attribution with `<CR>` to show commit, `~` to drill into history
- **TUI integration** — `arrange`, `split`, `diffedit`, `resolve` run in `:terminal`
- **Smart completion** — tab completion for jj commands, subcommands, and revisions/bookmarks
- **Browse** — open current file on GitHub/GitLab from Neovim
- **Divergence protection** — mutation commands warn and refuse on divergent revisions
- **AI review workflow** (optional, via [redline.nvim](https://github.com/martintrojer/redline.nvim)) — capture comments from unified diffs, show buffers, and status inline diffs into a shared AI-ready review packet

## Requirements

- Neovim 0.10+
- [Jujutsu](https://github.com/martinvonz/jj) installed and available in PATH
- [fugitive-core.nvim](https://github.com/martintrojer/fugitive-core.nvim)

### Optional

- [redline.nvim](https://github.com/martintrojer/redline.nvim) — AI review
  comment capture (`cR`/`gR` keymaps). Without it, everything else works
  normally; review keymaps just won't appear.

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{ "martintrojer/jj-fugitive", dependencies = { "martintrojer/fugitive-core.nvim" } }
-- For AI review support:
-- { "martintrojer/jj-fugitive", dependencies = { "martintrojer/fugitive-core.nvim", "martintrojer/redline.nvim" } }
```

### vim.pack (Neovim 0.12+)

```lua
vim.pack.add("martintrojer/fugitive-core.nvim")
vim.pack.add("martintrojer/jj-fugitive")
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use { "martintrojer/jj-fugitive", requires = { "martintrojer/fugitive-core.nvim" } }
```

### Manual

```bash
git clone https://github.com/martintrojer/fugitive-core.nvim ~/.local/share/nvim/site/pack/plugins/start/fugitive-core.nvim
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
| `:J push [args]` | Push to remote (jj git push) |
| `:J fetch [args]` | Fetch from remote (jj git fetch) |
| `:J browse` / `:JBrowse` | Open current file on remote |
| `:J <any>` | Pass through to jj (e.g. `:J new`, `:J squash`, `:J arrange`) |

## AI Review Workflow

Requires [redline.nvim](https://github.com/martintrojer/redline.nvim) (optional
dependency). Without it, review keymaps are not mapped and everything else works
normally.

From unified diff buffers, commit show buffers, and expanded status inline
diffs:

```
  cR        Add review comment for the current diff line
  gR        Open the shared review buffer
```

The review buffer is a shared scratch buffer formatted as an AI-ready review
packet. It includes a preamble for the AI model, jj repo context, and numbered
review items with file, revision, hunk, selected line, and your comment.

The review buffer also has lightweight navigation:

```
  gb        Switch to bookmark view
  gl        Switch to log view
  gs        Switch to status view
  q         Close
  g?        Help
```

Review capture is supported in unified diff buffers, show buffers, and status
inline diffs. Side-by-side diff mode is intentionally not supported.

## Log View

The log view is the primary hub. Open with `:J` or `:J log`.

```
Commit actions:
  <CR>      Show commit details (jj show)
            Show buffers also support `cR` and `gR` for review capture/navigation
  d         Show diff for commit
  cc        Describe (edit commit message)
  e         Edit at commit (jj edit)
  n         New change after commit (jj new)
  b         Create/move bookmark to commit
  A         Abandon commit (jj abandon)

Rebase:
  rw        Rebase @/@- onto cursor (children stay)
  rs        Rebase prompted source+desc onto cursor
  rS        Rebase cursor+desc onto prompted destination
  rr        Rebase prompted revision onto cursor (children stay)
  rR        Rebase cursor onto prompted destination (children stay)
  rb        Rebase prompted branch onto cursor
  rB        Rebase cursor branch onto prompted destination
  ra        Insert prompted revision after cursor
  rA        Insert cursor after prompted destination

Squash:
  gqw       Squash @/@- into cursor
  gqs       Squash prompted revision into cursor
  gqS       Squash cursor into prompted revision

Views:
  gb        Switch to bookmark view
  gC        Toggle compact/comfortable log layout
  gR        Open review buffer
  gs        Switch to status view

Other:
  ga        Show jj aliases
  gu        Undo last jj operation
  +/=       Show more commits
  R         Refresh
  q         Close
  g?        Help
```

## Status View

Open with `:J status` or `:J st`. Shows changed files in the working copy.

```
  <CR>      Open file
  o         Open file in split
  =         Toggle inline diff (fugitive-style)
  cR        Add review comment from inline diff line
  gR        Open shared review buffer
  d         Show diff for file
  D         Side-by-side diff
  cc        Describe working copy
  S         Split working copy (jj split TUI)
  x         Restore file from parent (@-)
  gb        Switch to bookmark view
  gl        Switch to log view
  ga        Show jj aliases
  gu        Undo last jj operation
  R         Refresh
  q         Close
  g?        Help
```

## Bookmark Management

Open with `:J bookmark`.

```
  c         Create bookmark (prompts for name and revision)
  d         Delete bookmark under cursor
  go        Edit at bookmark's revision
  m         Move bookmark to revision
  t         Track remote bookmark
  u         Untrack remote bookmark
  p         Push bookmark to remote
  f         Fetch from remote
  gR        Open shared review buffer
  gl        Switch to log view
  gs        Switch to status view
  ga        Show jj aliases
  gu        Undo last jj operation
  R         Refresh
  q         Close
  g?        Help
```

## Diff View

Open with `:J diff` or `:J diff <file>`.

```
  cR        Add review comment for current diff line
  gR        Open shared review buffer
  D         Side-by-side diff (opens in new tab with diffthis)
  o         Open file in editor
  gb        Switch to bookmark view
  gl        Switch to log view
  gs        Switch to status view
  [c / ]c   Navigate changes
  q         Close
  g?        Help
```

Review comments append to a shared scratch buffer formatted as an AI-ready
review packet, so the whole buffer can be pasted as-is into an AI review
prompt. Review comments are supported in unified diff and show buffers, plus
status inline diffs, but not in side-by-side diff mode.

## Annotate / Blame

Open with `:J annotate` or `:J blame`. Shows per-line attribution in a
scroll-locked split alongside the source file.

```
  <CR>      Show commit for this line
  ~         Re-annotate at parent of this line's change
  gb        Switch to bookmark view
  gl        Switch to log view
  gs        Switch to status view
  q         Close annotation
  g?        Help
```

## Describe & Commit

`:J describe [rev]` opens an editor buffer for the commit message. `:J commit` does the same but also creates a new change after saving. Lines starting with `#` are ignored. Save with `:w`.

```
  :w        Save description
  gb        Switch to bookmark view
  gl        Switch to log view
  gs        Switch to status view
  q         Abort (close without saving)
  g?        Help
```

## License

MIT
