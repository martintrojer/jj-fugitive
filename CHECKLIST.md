# Manual Test Checklist

## Test Repo Setup

```bash
# Create a fresh test repo
mkdir -p /tmp/jj-fugitive-test
cd /tmp/jj-fugitive-test
rm -rf .jj .git
git init && jj git init --colocate .

# Add some files and commits
echo "# Test Project" > README.md
echo "hello" > file1.txt
echo "world" > file2.txt
mkdir -p src
echo 'print("hello")' > src/main.py
jj commit -m "initial commit"

# Create working copy changes
echo "modified" >> file1.txt
echo "new file" > file3.txt
jj describe -m "add file3 and modify file1"

# Set up bookmark
jj bookmark create main -r @-

# Create a conflict: two branches from main modifying the same file
jj new main                       # branch A
echo "version A" > file1.txt
jj commit -m "branch A change"
jj bookmark create branchA -r @-
jj new main                       # branch B
echo "version B" > file1.txt
jj commit -m "branch B change"
jj bookmark create branchB -r @-
# Merge the two branches — creates conflict in file1.txt
jj new branchA branchB

# Verify — should show conflict markers in log
jj log
jj status
```

Open Neovim in the test repo:
```bash
cd /tmp/jj-fugitive-test
nvim file1.txt
```

---

## Checklist

### Log View (`:J` / `:J log`)

- [x] `:J` opens log view in a split
- [x] Log shows commits with colors (ANSI rendering)
- [x] Cursor starts on first commit line
- [x] `j`/`k` navigates between lines
- [x] `<CR>` on a commit opens show buffer with details
- [x] `d` on a commit opens diff buffer
- [x] Show/diff buffers have `g?` help and `q` to close
- [x] `D` in commit diff buffer opens file picker for side-by-side
- [x] Side-by-side shows correct file content at revision vs parent
- [x] `e` on a commit runs `jj edit` and refreshes log
- [x] `n` on a commit runs `jj new` and refreshes log
- [x] `S` on a commit prompts confirm, runs `jj squash`
- [x] `A` on a commit prompts confirm, runs `jj abandon`
- [x] `cc` on a commit opens describe buffer
- [x] `b` on a commit prompts for bookmark name, creates/moves it
- [x] `+` / `=` expands log (shows more commits with `--limit`)
- [x] `R` refreshes the log
- [x] `q` closes the log
- [x] `g?` shows help popup
- [x] Opening `:J` again reuses existing log buffer

### Conflict handling (from log view)

- [x] Log shows `(conflict)` marker on merge commit
- [x] `A` on the conflict merge commit abandons it, log refreshes cleanly
- [x] `n` on a branch commit (branchA/branchB) creates new change, log refreshes
- [x] `<CR>` on the conflict commit shows details
- [x] `d` on the conflict commit shows diff (empty for empty merge)

### Rebase (from log view)

- [x] `grd` on a commit prompts confirm, rebases `@` onto it
- [x] `grs` prompts for source revision, rebases onto commit (wired, not tested)
- [x] `grb` prompts for branch revision, rebases onto commit (wired, not tested)

### Diff View (`:J diff`)

- [x] `:J diff` on a modified file shows unified diff
- [x] `:J diff file1.txt` shows diff for specific file
- [x] `:J diff` with no changes shows "No changes" message
- [x] `D` opens side-by-side diff in new tab
- [x] Side-by-side shows left (parent) and right (working copy)
- [x] Side-by-side has syntax highlighting for file type
- [x] `o` opens the file in editor
- [x] `q` closes diff buffer
- [x] `g?` shows help popup

### Describe (`:J describe`)

- [x] `:J describe` opens editor with current `@` description
- [x] `:J describe <rev>` opens editor for specific revision
- [x] Buffer has `#` comment lines at top
- [x] Cursor starts after comment lines
- [x] `:w` saves description and closes buffer
- [x] `q` aborts without saving
- [x] Comment lines are filtered out on save
- [x] Empty message clears description (jj supports this)
- [x] Log refreshes after save

### Commit (`:J commit`)

- [x] `:J commit` opens editor with current description
- [x] `:w` runs `jj commit -m` and creates new change
- [x] Log refreshes after commit

### Bookmark Management (`:J bookmark`)

- [x] `:J bookmark` opens bookmark buffer
- [x] Shows all bookmarks with tracking info
- [x] `c` prompts for name and revision, creates bookmark
- [x] `d` on a bookmark prompts confirm, deletes it
- [x] `m` on a bookmark prompts for revision, moves it
- [ ] `t` tracks remote bookmark (needs remote)
- [ ] `u` untracks remote bookmark (needs remote)
- [ ] `p` pushes bookmark to remote (needs remote)
- [ ] `f` fetches from remote (needs remote)
- [x] `R` refreshes bookmark list
- [x] `q` closes bookmark buffer
- [x] `g?` shows help popup

### Status View (`:J status`)

- [x] `:J status` opens status buffer
- [x] Shows changed files with M/A/D indicators
- [x] `<CR>`/`o` opens file
- [x] `d` shows diff for file
- [x] `D` opens side-by-side diff
- [x] `x` restores file from parent (with confirm)
- [x] `=` toggles inline diff for file (fugitive-style)
- [x] `R` refreshes
- [x] `q` closes
- [x] `g?` shows help

### Annotate / Blame (`:J annotate`)

- [x] `:J annotate` shows annotations for current file
- [x] `:J blame` works as alias
- [x] `:J annotate <file>` annotates specific file
- [x] Scroll-locked with source buffer
- [x] `<CR>` opens commit view (tab or botright split depending on config)
- [x] `q` closes annotation
- [x] `g?` shows help

### Browse (`:JBrowse`)

- [x] `:JBrowse` opens URL or copies to clipboard
- [x] Works with current file and line number
- [x] Shows error when not in a repo or no remote

### Command Passthrough

- [x] `:J new` creates new change, refreshes log
- [x] `:J squash` squashes, refreshes log (via `S` in log)
- [x] `:J abandon` abandons, refreshes log (via `A` in log)
- [x] `:J arrange` opens in terminal tab (TUI command)
- [x] `:J split` opens in terminal tab (TUI command)
- [ ] `:J diffedit` opens in terminal tab (TUI command, not tested)
- [ ] `:J resolve` opens in terminal tab (TUI command, not tested)
- [x] TUI terminal closes cleanly and refreshes log
- [x] Unknown commands pass through to jj and print output

### Completion

- [x] `:J <Tab>` shows jj commands
- [x] `:J git <Tab>` shows git subcommands
- [x] `:J bookmark <Tab>` shows bookmark subcommands

### Edge Cases

- [x] Works from a subdirectory of the repo
- [x] `:J` outside a jj repo shows error message
- [x] Multiple `:J` calls reuse the same log buffer
- [x] Closing and reopening log works cleanly

---

## Test Log

| Date | Tester | Notes |
|------|--------|-------|
| 2026-03-17 | mtrojer | First pass, core functionality verified. Found and fixed: popup focus, change ID vs commit hash, editor hang (JJ_EDITOR), describe abort/close, rebase keybindings (r->gr prefix) |
| 2026-03-17 | mtrojer | Second pass: status view, bookmark CRUD, describe, commit, completion, edge cases. Added annotate, inline diff, TUI support, side-by-side from commit diff |
| 2026-03-18 | mtrojer | Config fixes (require path bug), tab/split mode, annotate CR behavior, silent file show for side-by-side, stray buffer cleanup |
| 2026-03-18 | mtrojer | Third pass: conflict handling, annotate/blame, TUI commands (arrange, split), inline diff toggle, bookmark refresh. Only remote bookmark ops and diffedit/resolve untested (need remote/conflicts) |
