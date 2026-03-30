# TODO

- [ ] Write tests for v2

## Architecture

- [ ] Fully async `run_jj` using `vim.system()` callbacks — currently blocks with `:wait()`
- [ ] Reduce subprocess count per action — `rev_label()` and `working_copy_source()` each spawn a process before the actual command; consider batching or caching

## UX

- [ ] No visual feedback during commands — no spinner or "Running..." message while editor is frozen
- [ ] No blame navigation — can't re-blame at a parent revision from annotate view
