# TODO

## UX

- [ ] Blame history stack — `~` goes to parent but no way to go back to child

## Known issues

- [ ] `log.lua` template construction with user config could produce invalid jj expressions
- [ ] `ui.lua` `file_at_rev` bypasses `run_jj` and uses `vim.fn.system` directly (intentionally silent)
- [ ] `warn_divergent` adds a synchronous jj call before every mutation — could cache from log output

## Tests

- [ ] Write tests
