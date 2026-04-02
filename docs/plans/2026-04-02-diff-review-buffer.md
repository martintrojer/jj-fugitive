# Implementation Plan: Diff Review Buffer

**Date:** 2026-04-02
**Design Doc:** In-thread feature discussion on unified diff code review buffers
**Estimated Tasks:** 11

## Overview
Add lightweight review comments to every unified diff surface in the plugin. A user can place the cursor on a diff line, enter a comment, and append a structured section to a shared review buffer intended for copy-paste into an AI prompt.

## Scope
- In scope: unified diff buffers from `:J diff`, commit diff buffers opened from log, and inline status diffs opened with `=`.
- In scope: a shared review buffer with a jj-specific header and append-only sections.
- In scope: convenience keybindings to jump to the review buffer from buffers where review actions make sense.
- Out of scope: side-by-side diff review support, persistence, dedicated edit/remove workflows, automatic save/export.

## Buffer Shape
The review buffer should be optimized for pasting into an AI prompt. Start with a stable repo-aware header, then append one section per comment.

Suggested shape:

```text
# jj Review Buffer
# Repository: /abs/path/to/repo
# Source: jj-fugitive unified diff review
# Instructions: Copy this buffer into your AI review prompt. Edit freely in Neovim before sending.

## Comment 1
File: path/to/file.lua
Revision: @
Line: @@ -10,6 +10,8 @@
Change: +local value = compute()
Comment:
This needs to handle nil input.
```

The exact labels can change during implementation, but every section must include file, revision, and comment. Include the current diff line text too, since that materially improves the AI prompt.

## Tasks

### Task 1: Create the planning doc directory
**File:** `docs/plans/2026-04-02-diff-review-buffer.md`
**Time:** ~2 minutes

**Steps:**
1. Create the `docs/plans/` directory if it does not already exist.
2. Add this implementation plan file.

**Code:**
```text
mkdir -p docs/plans
```

**Verify:**
```bash
test -f docs/plans/2026-04-02-diff-review-buffer.md
```

**Commit:** `docs: add diff review buffer implementation plan`

---

### Task 2: Add a dedicated review buffer module
**File:** `lua/jj-fugitive/review.lua`
**Time:** ~5 minutes

**Steps:**
1. Create a new module responsible for creating, finding, showing, and appending to the shared review buffer.
2. Use the existing scratch-buffer helpers from `ui.lua`.
3. Name the buffer consistently, for example `jj-review`.

**Code:**
```lua
local M = {}

function M.show()
  -- find or create shared review buffer
end

function M.append(entry)
  -- append section to end of review buffer
end

return M
```

**Verify:**
```bash
luacheck lua/jj-fugitive/review.lua
```

**Commit:** `feat: add review buffer module`

---

### Task 3: Define review buffer content and formatting helpers
**File:** `lua/jj-fugitive/review.lua`
**Time:** ~5 minutes

**Steps:**
1. Add a function that creates the initial header for jj repositories.
2. Add a formatter for appended review sections.
3. Ensure sections are append-only and leave the buffer modifiable so the user can edit freely afterward.

**Code:**
```lua
local function header_lines(repo_root)
  return {
    "# jj Review Buffer",
    "# Repository: " .. repo_root,
    "# Source: jj-fugitive unified diff review",
    "# Instructions: Copy this buffer into your AI review prompt. Edit freely in Neovim before sending.",
    "",
  }
end
```

**Verify:**
```bash
luacheck lua/jj-fugitive/review.lua
```

**Commit:** `feat: define review buffer format`

---

### Task 4: Capture diff context metadata from unified diff buffers
**File:** `lua/jj-fugitive/diff.lua`
**Time:** ~5 minutes

**Steps:**
1. Add buffer-local metadata when unified diff buffers are created or refreshed.
2. Store at least `file`, `rev`, and whether the buffer represents working copy or a specific revision.
3. For whole-tree diffs, prepare to infer the active file from nearby `diff --git` headers around the cursor.

**Code:**
```lua
vim.api.nvim_buf_set_var(bufnr, "jj_review_context", {
  file = filename,
  rev = rev or "@",
  kind = "unified_diff",
})
```

**Verify:**
```bash
luacheck lua/jj-fugitive/diff.lua
```

**Commit:** `feat: store unified diff review context`

---

### Task 5: Extend `diff.lua` to support explicit revisions
**File:** `lua/jj-fugitive/diff.lua`
**Time:** ~5 minutes

**Steps:**
1. Refactor `M.show()` so callers can pass structured options instead of only a filename string.
2. Preserve existing command behavior for `:J diff`.
3. Allow log diff buffers to reuse the same code path with `rev = <commit id>`.

**Code:**
```lua
function M.show(opts)
  opts = type(opts) == "table" and opts or { file = opts }
  local output = get_diff(opts.file, opts.rev)
end
```

**Verify:**
```bash
luacheck lua/jj-fugitive/diff.lua
```

**Commit:** `refactor: unify diff buffer creation paths`

---

### Task 6: Add review actions to unified diff buffers
**File:** `lua/jj-fugitive/diff.lua`
**Time:** ~5 minutes

**Steps:**
1. Add a buffer-local keymap to prompt for a review comment on the current line.
2. On submit, append a formatted section to the shared review buffer.
3. Add a separate convenience keymap to open or jump to the review buffer directly.
4. Update the diff help popup text.

**Code:**
```lua
ui.map(bufnr, "n", "cR", function()
  review.comment_current_line(bufnr)
end)

ui.map(bufnr, "n", "gR", function()
  review.show()
end)
```

**Verify:**
```bash
luacheck lua/jj-fugitive/diff.lua lua/jj-fugitive/review.lua
```

**Commit:** `feat: add review actions to unified diff view`

---

### Task 7: Route log commit diffs through the shared unified diff path
**File:** `lua/jj-fugitive/log.lua`
**Time:** ~5 minutes

**Steps:**
1. Replace the custom inline diff buffer creation in log with a call into `require("jj-fugitive.diff").show({ rev = id })`.
2. Keep the existing `D` side-by-side behavior unchanged.
3. Ensure the log-opened diff gains the same review actions as regular diff buffers.

**Code:**
```lua
ui.map(bufnr, "n", "d", function()
  require("jj-fugitive.diff").show({ rev = id })
end)
```

**Verify:**
```bash
luacheck lua/jj-fugitive/log.lua lua/jj-fugitive/diff.lua
```

**Commit:** `refactor: reuse unified diff buffer for log diffs`

---

### Task 8: Add review support to inline status diffs
**File:** `lua/jj-fugitive/status.lua`
**Time:** ~5 minutes

**Steps:**
1. Mark inserted inline diff lines with enough metadata to recover the file and working-copy revision.
2. Add a keybinding that works when the cursor is on an inline diff line.
3. Add a convenience binding in status view to jump to the review buffer.
4. Ignore review-comment actions when the cursor is on a plain status line rather than an inline diff line.

**Code:**
```lua
-- store inline diff ranges keyed by start/end line and file
vim.api.nvim_buf_set_var(bufnr, "jj_status_inline_diffs", state)
```

**Verify:**
```bash
luacheck lua/jj-fugitive/status.lua lua/jj-fugitive/review.lua
```

**Commit:** `feat: add review actions to inline status diffs`

---

### Task 9: Implement diff-line parsing and fallback file detection
**File:** `lua/jj-fugitive/review.lua`
**Time:** ~5 minutes

**Steps:**
1. Add helpers that read the current cursor line and surrounding lines.
2. For unified diff buffers spanning multiple files, walk backward to the nearest `diff --git` header to determine the active file.
3. Capture hunk headers like `@@ ... @@` when present so the AI prompt has local context.

**Code:**
```lua
local function find_file_for_cursor(lines, cursor_line)
  for i = cursor_line, 1, -1 do
    local file = lines[i]:match("^diff %-%-git a/(.-) b/")
    if file then
      return file
    end
  end
end
```

**Verify:**
```bash
luacheck lua/jj-fugitive/review.lua
```

**Commit:** `feat: infer file and hunk context for review comments`

---

### Task 10: Document the new review workflow
**File:** `README.md`
**Time:** ~5 minutes

**Steps:**
1. Add the new review capability to the feature list.
2. Document the new keybindings in Diff View and Status View sections.
3. Mention that the review buffer is intended for AI prompt copy-paste and is append-only by default.

**Code:**
```markdown
- **Review buffer** — add comments from unified diffs and collect them in a shared AI-friendly buffer
```

**Verify:**
```bash
rg -n "review buffer|AI-friendly|cr|gr" README.md
```

**Commit:** `docs: document unified diff review workflow`

---

### Task 11: Update Vim help for the review workflow
**File:** `doc/jj-fugitive.txt`
**Time:** ~5 minutes

**Steps:**
1. Add review keybindings to the Diff View and Status View help sections.
2. Add a short subsection describing the review buffer purpose and scope.
3. Explicitly note that side-by-side review comments are not supported.

**Code:**
```text
REVIEW BUFFER                                   *jj-fugitive-review*

Unified diff views can append comments to a shared review buffer for AI-assisted review workflows.
```

**Verify:**
```bash
rg -n "REVIEW BUFFER|review buffer|side-by-side" doc/jj-fugitive.txt
```

**Commit:** `docs: add review buffer help`

---

## Progress Tracker

- [x] Task 1: Create the planning doc directory
- [x] Task 2: Add a dedicated review buffer module
- [x] Task 3: Define review buffer content and formatting helpers
- [x] Task 4: Capture diff context metadata from unified diff buffers
- [x] Task 5: Extend `diff.lua` to support explicit revisions
- [x] Task 6: Add review actions to unified diff buffers
- [x] Task 7: Route log commit diffs through the shared unified diff path
- [x] Task 8: Add review support to inline status diffs
- [x] Task 9: Implement diff-line parsing and fallback file detection
- [x] Task 10: Document the new review workflow
- [x] Task 11: Update Vim help for the review workflow

## Notes

- Prefer one shared review buffer per repo, not per diff window.
- Keep side-by-side diff support out of the initial implementation.
- Review bindings use `cR` for comment capture and `gR` to open the shared review buffer, staying closer to Fugitive-style terse commands while avoiding fragile prefixes.
- Do not build custom editing UX for the review buffer. Users can edit, reorder, or delete content manually in Neovim.
- Verification used `luacheck --no-cache lua/jj-fugitive/ plugin/` because the default luacheck cache path is outside the sandbox.
- Verification used `stylua --check lua/jj-fugitive/ plugin/`; Markdown and Vim help files were checked by inspection instead of `stylua`.
