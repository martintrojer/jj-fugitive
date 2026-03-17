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

# Verify
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
- [x] `e` on a commit runs `jj edit` and refreshes log
- [x] `n` on a commit runs `jj new` and refreshes log
- [x] `s` on a commit prompts confirm, runs `jj squash`
- [x] `A` on a commit prompts confirm, runs `jj abandon`
- [x] `cc` on a commit opens describe buffer
- [x] `b` on a commit prompts for bookmark name, creates/moves it
- [x] `+` / `=` expands log (shows more commits with `--limit`)
- [x] `R` refreshes the log
- [x] `q` closes the log
- [x] `g?` shows help popup
- [x] Opening `:J` again reuses existing log buffer

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
- [ ] `t` tracks remote bookmark
- [ ] `u` untracks remote bookmark
- [ ] `p` pushes bookmark to remote
- [ ] `f` fetches from remote
- [ ] `R` refreshes bookmark list
- [x] `q` closes bookmark buffer
- [x] `g?` shows help popup

### Browse (`:JBrowse`)

- [ ] `:JBrowse` opens URL or copies to clipboard
- [ ] Works with current file and line number
- [x] Shows error when not in a repo or no remote

### Command Passthrough

- [x] `:J new` creates new change, refreshes log
- [x] `:J squash` squashes, refreshes log (via `s` in log)
- [x] `:J abandon` abandons, refreshes log (via `A` in log)
- [ ] `:J arrange` opens in terminal split (TUI command)
- [ ] `:J split` opens in terminal split (TUI command)
- [ ] `:J diffedit` opens in terminal split (TUI command)
- [ ] `:J resolve` opens in terminal split (TUI command)
- [ ] TUI terminal closes cleanly and refreshes log
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
