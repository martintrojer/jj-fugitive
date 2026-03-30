# TODO

- [ ] Write tests for v2

## Bugs / Correctness

- [x] `run_jj` uses `lcd` (window-local) — replaced with `vim.system()` and `-R` flag
- [x] `describe.lua` — use `-m` as separate arg instead of `--message=` concatenation
- [x] `browse.lua` — fixed operator precedence bug in `get_default_rev`
- [x] `annotate.lua` — `q` now uses `ui.close_cmd()`

## Architecture

- [ ] Fully async `run_jj` using `vim.system()` callbacks — currently blocks with `:wait()`
- [ ] Reduce subprocess count per action — `rev_label()` and `working_copy_source()` each spawn a process before the actual command; consider batching or caching

## UX

- [ ] No visual feedback during commands — no spinner or "Running..." message while editor is frozen
- [ ] `diff.lua` opens a new buffer each time — no buffer reuse like log/status/bookmarks
- [ ] Annotate has no `R` (refresh) keybinding
- [x] Side-by-side diff `o` keybinding now uses `ui.close_cmd()`
- [ ] Completion doesn't suggest revisions or bookmarks for flags like `-r`

## Code Quality

- [x] `diff.lua` — removed double `ui` require in `M.show()`
- [x] `browse.lua` — removed unnecessary `get_init()` wrapper
- [x] `ansi.lua` top-level require is fine — Lua caches modules, only loads on first use

## Missing Features

- [ ] No `jj split` from status view (JJ equivalent of fugitive's stage/unstage)
- [ ] No blame navigation — can't re-blame at a parent revision from annotate view
- [ ] No dedicated `:J push`/`:J pull` shortcuts
