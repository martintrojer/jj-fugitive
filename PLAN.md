# jj-fugitive v2 — Rewrite Plan

## Philosophy

Strip back to essentials. The current codebase has grown organically and accumulated
complexity: interactive command buffers that don't fully work (split, diffedit, resolve),
over-engineered completion, status buffer with too many keybindings, and view navigation
state management that's fragile.

v2 focuses on **five core workflows** that map cleanly to how people actually use jj,
while staying true to fugitive's design: specialized read-only buffers with contextual
keybindings, and a single `:J` entry point.

## Core Workflows

### 1. Log Viewing (`:J log`)

The centerpiece. jj's log is richer than git's — it shows the DAG, bookmarks, and
working copy state natively. This should be the primary navigation hub.

**Keep from v1:**
- ANSI color parsing from `jj log --color always` (ansi.lua is solid)
- Commit ID extraction from log lines
- Expand view (`+` / `=` to load more commits)

**Simplify:**
- Remove emoji indicators (👉🔀🌱 etc.) — jj's native output already has `@`, `◆`, `○`
- Remove parent/child navigation (P/N) — cursor movement is sufficient
- Remove the `update_current` buffer-reuse pattern — just replace buffer content directly

**Keybindings:**
- `<CR>` — show commit details (`jj show --color always --git <id>`)
- `d` — show diff for commit
- `e` — `jj edit <id>` (edit at this commit)
- `n` — `jj new <id>` (new change after this commit)
- `s` — `jj squash -r <id>` (squash into parent)
- `A` — `jj abandon <id>`
- `b` — enter bookmark mode (see §2)
- `r` — enter rebase mode (see §3)
- `R` — refresh
- `q` — close
- `g?` — help

### 2. Bookmark Management (`:J bookmark`)

jj bookmarks are the equivalent of git branches. Needs first-class support for
create, delete, move, and list — plus git push/fetch integration.

**New dedicated buffer** showing output of `jj bookmark list --all -T <template>` with
color. Accessible from log view via `b` or standalone via `:J bookmark`.

**Keybindings (in bookmark buffer):**
- `c` — create bookmark at revision under cursor (prompt for name)
- `d` — delete bookmark under cursor
- `m` — move bookmark to a different revision
- `t` — track remote bookmark
- `u` — untrack remote bookmark
- `p` — `jj git push --bookmark <name>`
- `f` — `jj git fetch`
- `R` — refresh
- `q` — close

**From log view:** pressing `b` on a commit line opens a prompt to create/move a
bookmark to that commit.

### 3. Rebase & Stack Management (`:J rebase`, `:J arrange`)

jj's killer feature. `jj rebase` for manual moves, `jj arrange` (new in recent jj)
for automatic stack ordering.

**Approach:** No dedicated buffer. Actions triggered from log view or via `:J` commands.

**From log view:**
- `r` — rebase mode:
  - `rd` — rebase current (`@`) onto commit under cursor (`jj rebase -d <id>`)
  - `rs` — rebase source onto dest (prompt for source rev)
  - `rb` — rebase branch (`jj rebase -b <rev> -d <dest>`)

**Standalone commands:**
- `:J rebase -s <src> -d <dest>` — pass through to jj
- `:J arrange` — run `jj arrange` (auto-order stack)
- `:J parallelize` — run `jj parallelize` on revset

After any rebase/arrange operation, refresh the log view if open.

### 4. Diff Viewing (`:J diff`)

Show diffs with proper ANSI color rendering. Two modes: unified and side-by-side.

**Keep from v1:**
- ANSI color parsing for `jj diff --color always --git`
- Side-by-side using Neovim's built-in `diffthis`
- File-specific and all-changes diffs

**Simplify:**
- Remove format selector (f key) — always use git format
- Remove the toggle state tracking — just provide `d` (unified) and `D` (side-by-side)
- Remove `update_current` buffer reuse — simpler buffer lifecycle

**Keybindings (in diff buffer):**
- `q` — close
- `o` — open file in editor
- `D` — switch to side-by-side (from unified)
- `[c` / `]c` — navigate hunks (vim standard)
- `g?` — help

### 5. Editing, Squash, Describe (`:J describe`, `:J new`, `:J commit`)

Working copy management. These are the day-to-day operations.

**Keep from v1:**
- `describe` buffer with `BufWriteCmd` to save via `jj describe -m`
- `commit` buffer similarly

**Simplify:**
- Remove `split`, `diffedit`, `resolve` stubs — they just show error messages anyway
- Remove `is_interactive_command` detection — handle explicitly in the dispatcher
- `describe` and `commit` are the only commands that get editor buffers

**Commands:**
- `:J` (no args) — show log (not status — log is the better hub in jj)
- `:J describe [rev]` — open describe buffer
- `:J commit` — open commit buffer
- `:J new [rev]` — create new change
- `:J edit <rev>` — edit at revision
- `:J squash [-r rev]` — squash into parent
- `:J abandon [rev]` — abandon revision

All mutating commands refresh the log buffer if it's open.

## Architecture

```
lua/jj-fugitive/
├── init.lua          # Entry point: :J dispatcher, repo detection, jj command runner
├── log.lua           # Log buffer: display, keybindings, commit actions
├── diff.lua          # Diff buffer: unified + side-by-side
├── bookmark.lua      # Bookmark buffer: list, create, delete, push/fetch
├── describe.lua      # Describe/commit editor buffers
├── ansi.lua          # ANSI color parsing (keep from v1, mostly unchanged)
├── ui.lua            # Shared utilities: scratch buffers, keymaps, popups
└── completion.lua    # Command completion (simplified)

plugin/jj-fugitive.lua  # Register :J, :JBrowse commands
```

**Removed modules:**
- `status.lua` — log replaces status as the primary view
- `browse.lua` — keep as-is or inline into init.lua (it's small and clean)

**Key design changes:**
- `init.lua` becomes much thinner — just a dispatcher + `run_jj()` helper
- No `run_jj_command_from_module` indirection — export `run_jj()` directly
- No `BUFFER_PATTERNS` table — each module owns its buffer identity
- No `repo_root_cache` — use `vim.fs.find('.jj', { upward = true })` (Neovim 0.8+)
- No `previous_view` / `store_view_context` — each buffer is independent, `q` closes

## Implementation Phases

### Phase 1: Foundation
- [ ] Create `v2` branch
- [ ] New `init.lua`: repo detection with `vim.fs.find`, `run_jj()` command runner, `:J` dispatcher
- [ ] New `ui.lua`: `create_scratch_buffer`, `map`, `err_write`, `confirm`, `set_statusline`
- [ ] Keep `ansi.lua` from v1 (it works well)
- [ ] New `plugin/jj-fugitive.lua`: register `:J` command

### Phase 2: Log View
- [ ] New `log.lua`: show log with ANSI colors, commit extraction, keybindings
- [ ] Actions from log: `e` (edit), `n` (new), `s` (squash), `A` (abandon)
- [ ] Expand view with `+`/`=`
- [ ] `<CR>` to show commit details, `d` for diff

### Phase 3: Diff View
- [ ] New `diff.lua`: unified diff with ANSI colors
- [ ] Side-by-side diff with `diffthis`
- [ ] Navigate from log view commit -> diff

### Phase 4: Describe & Commit
- [ ] New `describe.lua`: editor buffers for `describe` and `commit`
- [ ] `BufWriteCmd` to save via jj
- [ ] Refresh log on save

### Phase 5: Bookmark Management
- [ ] New `bookmark.lua`: list bookmarks with status
- [ ] Create, delete, move bookmarks
- [ ] Push/fetch integration

### Phase 6: Rebase & Arrange
- [ ] Rebase keybindings in log view (`rd`, `rs`, `rb`)
- [ ] `:J arrange` passthrough
- [ ] `:J parallelize` passthrough
- [ ] Refresh log after operations

### Phase 7: Completion & Polish
- [ ] Simplified completion (parse `jj --help` output, no deep flag parsing)
- [ ] `:JBrowse` (carry forward from v1)
- [ ] Help popups (`g?` in each buffer)
- [ ] Tests

## What We're Dropping

| Feature | Reason |
|---|---|
| Status buffer | Log is the better hub for jj (no staging area) |
| Interactive split/diffedit/resolve | Were stubs showing error messages |
| `is_interactive_command` detection | Explicit dispatch is simpler |
| Format selector in diff view | Over-engineering; git format is fine |
| Emoji indicators in log | jj's native symbols are better |
| `update_current` buffer reuse | Complex state management for little gain |
| `previous_view` navigation | Each buffer is independent |
| `repo_root_cache` | `vim.fs.find` is fast enough |
| Deep flag completion | Diminishing returns; basic completion is fine |
