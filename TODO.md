# TODO

## Architecture

- [ ] `log.lua` is 820+ lines — mutation boilerplate could be table-driven
- [ ] `rev_label` cache is module-level mutable state — could show stale data across repo switches
- [ ] `ui.lua` `file_at_rev` uses `vim.fn.system` and bypasses `run_jj` — no error feedback, env handling, or "running..." indicator
- [ ] `completion.lua` `invalidate_cache` called from `init.lua` — cross-module dependency

## Tests

- [ ] Behavioral tests for status file_from_line, bookmark_from_line, log rev extraction, annotate parsing
- [ ] Integration tests — headless test that creates buffer, calls show(), verifies content and keymaps

## Known issues

- [ ] `warn_divergent` adds a synchronous jj call before every mutation — could cache from log output
