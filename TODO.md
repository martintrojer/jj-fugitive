# TODO

- [ ] Write tests for v2
- [ ] No `jj status` awareness anywhere. After `jj edit`, modified files
  remain in the worktree but there's no way to see them from the plugin.
  Consider adding a status section to the log view, or a lightweight
  `:J status` command that shows changed files with file-level actions.
- [x] Keybinding conflict resolved: describe in log is now `cc` (like
  fugitive's commit), freeing `D` for side-by-side diff.
- [x] TUI commands (`arrange`, `split`, `diffedit`, `resolve`) now run
  in `:terminal` split instead of `vim.fn.system`. Log refreshes on exit.
- [ ] Side-by-side diff from log commit diff view (`d` in log) — hard because
  commit diffs span multiple files, and `diffthis` requires a single file.
  Would need a file picker or per-file navigation within the commit diff.
