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

- [ ] `:J` opens log view in a split
- [ ] Log shows commits with colors (ANSI rendering)
- [ ] Cursor starts on first commit line
- [ ] `j`/`k` navigates between lines
- [ ] `<CR>` on a commit opens show buffer with details
- [ ] `d` on a commit opens diff buffer
- [ ] Show/diff buffers have `g?` help and `q` to close
- [ ] `e` on a commit runs `jj edit` and refreshes log
- [ ] `n` on a commit runs `jj new` and refreshes log
- [ ] `s` on a commit prompts confirm, runs `jj squash`
- [ ] `A` on a commit prompts confirm, runs `jj abandon`
- [ ] `D` on a commit opens describe buffer
- [ ] `b` on a commit prompts for bookmark name, creates/moves it
- [ ] `+` / `=` expands log (shows more commits with `--limit`)
- [ ] `R` refreshes the log
- [ ] `q` closes the log
- [ ] `g?` shows help popup
- [ ] Opening `:J` again reuses existing log buffer

### Rebase (from log view)

- [ ] `rd` on a commit prompts confirm, rebases `@` onto it
- [ ] `rs` prompts for source revision, rebases onto commit
- [ ] `rb` prompts for branch revision, rebases onto commit

### Diff View (`:J diff`)

- [ ] `:J diff` on a modified file shows unified diff
- [ ] `:J diff file1.txt` shows diff for specific file
- [ ] `:J diff` with no changes shows "No changes" message
- [ ] `D` opens side-by-side diff in new tab
- [ ] Side-by-side shows left (parent) and right (working copy)
- [ ] Side-by-side has syntax highlighting for file type
- [ ] `o` opens the file in editor
- [ ] `q` closes diff buffer
- [ ] `g?` shows help popup

### Describe (`:J describe`)

- [ ] `:J describe` opens editor with current `@` description
- [ ] `:J describe @-` opens editor for parent revision
- [ ] Buffer has `#` comment lines at top
- [ ] Cursor starts after comment lines
- [ ] `:w` saves description via `jj describe -m`
- [ ] Comment lines are filtered out on save
- [ ] Empty message shows error, does not save
- [ ] Log refreshes after save

### Commit (`:J commit`)

- [ ] `:J commit` opens editor with current description
- [ ] `:w` runs `jj commit -m` and creates new change
- [ ] Log refreshes after commit

### Bookmark Management (`:J bookmark`)

- [ ] `:J bookmark` opens bookmark buffer
- [ ] Shows all bookmarks with tracking info
- [ ] `c` prompts for name and revision, creates bookmark
- [ ] `d` on a bookmark prompts confirm, deletes it
- [ ] `m` on a bookmark prompts for revision, moves it
- [ ] `t` tracks remote bookmark
- [ ] `u` untracks remote bookmark
- [ ] `p` pushes bookmark to remote
- [ ] `f` fetches from remote
- [ ] `R` refreshes bookmark list
- [ ] `q` closes bookmark buffer
- [ ] `g?` shows help popup

### Browse (`:JBrowse`)

- [ ] `:JBrowse` opens URL or copies to clipboard
- [ ] Works with current file and line number
- [ ] Shows error when not in a repo or no remote

### Command Passthrough

- [ ] `:J new` creates new change, refreshes log
- [ ] `:J squash` squashes, refreshes log
- [ ] `:J abandon` abandons, refreshes log
- [ ] `:J arrange` passes through to jj
- [ ] Unknown commands pass through to jj and print output

### Completion

- [ ] `:J <Tab>` shows jj commands
- [ ] `:J git <Tab>` shows git subcommands
- [ ] `:J bookmark <Tab>` shows bookmark subcommands

### Edge Cases

- [ ] Works from a subdirectory of the repo
- [ ] `:J` outside a jj repo shows error message
- [ ] Multiple `:J` calls reuse the same log buffer
- [ ] Closing and reopening log works cleanly

---

## Test Log

| Date | Tester | Notes |
|------|--------|-------|
|      |        |       |
