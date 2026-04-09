# Smoke Test Checklist

## Test Repo Setup

```bash
tmp=$(mktemp -d /tmp/jj-fugitive-test.XXXXXX)
cd "$tmp"
git init && jj git init --colocate .

echo "# Test Project" > README.md
echo "hello" > file1.txt
echo "world" > file2.txt
mkdir -p src
echo 'print("hello")' > src/main.py
jj commit -m "initial commit"

echo "modified" >> file1.txt
echo "new file" > file3.txt
jj describe -m "add file3 and modify file1"

jj bookmark create main -r @-
```

## Checklist

### Log (`:J` / `:J log`)

- [ ] `:J` opens log with ANSI colors
- [ ] `<CR>` opens commit detail, `q` returns to log
- [ ] `d` opens unified diff
- [ ] `D` opens side-by-side diff (file picker if multi-file), `q` returns
- [ ] `cc` edits commit message
- [ ] `e` edits at commit
- [ ] `n` creates new change after commit
- [ ] `A` abandons commit
- [ ] `b` creates/moves bookmark
- [ ] `rw` rebases @/@- onto cursor
- [ ] `rs`/`rS` rebase with source/dest prompts
- [ ] `gqw` squashes @/@- into cursor
- [ ] `gC` toggles compact/comfortable layout
- [ ] `gu` undoes last operation
- [ ] `R` refreshes, cursor stays in place
- [ ] `gs` → status, `gb` → bookmark, `gl` → back to log
- [ ] `g?` shows help

### Status (`:J status`)

- [ ] Shows changed files
- [ ] `=` toggles inline diff, `=` inside block collapses it
- [ ] `<CR>` opens file, `o` opens in split (status stays)
- [ ] `d` shows diff, `D` side-by-side
- [ ] `cc` describes working copy
- [ ] `S` opens split TUI
- [ ] `x` restores tracked file, deletes added file
- [ ] `dd` deletes file from filesystem
- [ ] `o/d/D/x` work from inside expanded inline diff

### Diff (`:J diff`)

- [ ] `:J diff` shows working copy diff
- [ ] `:J diff file1.txt` shows file-specific diff
- [ ] `D` opens side-by-side
- [ ] `o` opens file in editor

### Describe / Commit

- [ ] `:J describe` opens editor for `@`
- [ ] `:w` saves, `q` aborts
- [ ] `:J commit` describes and creates new change

### Bookmark (`:J bookmark`)

- [ ] `c` creates, `d` deletes, `m` moves
- [ ] `t` tracks, `u` untracks, `p` pushes, `f` fetches
- [ ] `go` edits at bookmark revision

### Annotate (`:J annotate`)

- [ ] Opens scroll-locked split
- [ ] `<CR>` opens commit detail
- [ ] `~` drills into parent, `<BS>` goes back
- [ ] `q` closes cleanly

### Browse (`:JBrowse`)

- [ ] Opens URL from file buffer
- [ ] Line number included

### Tab Completion

- [ ] `:J <tab>` completes commands
- [ ] `:J diff -r <tab>` completes revisions

### Close Behavior

- [ ] `q` never quits Neovim
- [ ] No stray `[No Name]` buffers accumulate
