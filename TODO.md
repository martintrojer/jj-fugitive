# TODO

## Architecture

- [ ] `log.lua` is 820+ lines — mutation boilerplate could be table-driven
- [ ] `rev_label` cache is module-level mutable state — could show stale data across repo switches
- [ ] `ui.lua` `file_at_rev` uses `vim.fn.system` and bypasses `run_jj` — inconsistent
- [ ] `completion.lua` `invalidate_cache` called from `init.lua` — cross-module dependency

## Cleanup

- [ ] `format_lines` nearly identical between `status.lua` and `bookmark.lua` — extract helper
- [ ] `unpack(parts, 2)` in push/fetch dispatch is fragile — use `vim.list_extend`

## Known issues

- [ ] `warn_divergent` adds a synchronous jj call before every mutation — could cache from log output

## Tests

- [ ] Write tests
