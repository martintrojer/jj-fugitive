# TODO

## UX

- [ ] Blame history stack — `~` goes to parent but no way to go back to child
- [ ] Revision completion in `completion.lua` is uncached and synchronous — can freeze in large repos
- [ ] Alias cache in `completion.lua` never invalidated within a session

## Known issues

- [ ] `log.lua` template construction with user config could produce invalid jj expressions
- [ ] `ui.lua` `file_at_rev` bypasses `run_jj` and uses `vim.fn.system` directly (intentionally silent)
- [ ] `warn_divergent` adds a synchronous jj call before every mutation — could cache from log output

## Tests

- [ ] Write tests
