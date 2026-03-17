# TODO

- [ ] Write tests for v2
- [ ] No `jj status` awareness anywhere. After `jj edit`, modified files
  remain in the worktree but there's no way to see them from the plugin.
  Consider adding a status section to the log view, or a lightweight
  `:J status` command that shows changed files with file-level actions.
- [ ] Keybinding conflict: `D` means side-by-side diff in diff view but
  describe in log view. Consider a different key for describe in log
  (e.g. `cc` like fugitive's commit, or `dd` to match `d` for diff).
- [x] TUI commands (`arrange`, `split`, `diffedit`, `resolve`) now run
  in `:terminal` split instead of `vim.fn.system`. Log refreshes on exit.
- [ ] Side-by-side diff from log commit diff view (`d` in log) — hard because
  commit diffs span multiple files, and `diffthis` requires a single file.
  Would need a file picker or per-file navigation within the commit diff.
