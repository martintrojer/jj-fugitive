# TODO

- [ ] Write tests for v2
- [x] `:J status` view: shows changed files with open, diff, side-by-side,
  and restore actions.
- [x] Keybinding conflict resolved: describe in log is now `cc` (like
  fugitive's commit), freeing `D` for side-by-side diff.
- [x] TUI commands (`arrange`, `split`, `diffedit`, `resolve`) now run
  in `:terminal` split instead of `vim.fn.system`. Log refreshes on exit.
- [ ] Side-by-side diff from log commit diff view (`d` in log) — hard because
  commit diffs span multiple files, and `diffthis` requires a single file.
  Would need a file picker or per-file navigation within the commit diff.
