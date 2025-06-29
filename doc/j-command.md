# The :J Command

The `:J` command is the primary interface for jj-fugitive, providing a universal gateway to all jujutsu operations with intelligent completion.

## Overview

The `:J` command acts as a smart wrapper around the `jj` command-line tool, offering:

- **Universal access** to all jj functionality
- **Intelligent tab completion** for commands, flags, and values
- **Context-aware suggestions** based on repository state
- **Automatic status refresh** after state-changing operations
- **Familiar vim-fugitive-style interface**

## Basic Usage

### Default Behavior

```vim
:J
```

When called without arguments, `:J` shows the interactive status buffer (equivalent to `:JStatus`).

### Running jj Commands

```vim
:J <command> [arguments...]
```

Any valid jj command can be executed through `:J`:

```vim
:J status
:J log
:J commit -m "Fix bug"
:J new -m "Start feature"
:J bookmark set main
:J abandon
:J squash
```

## Smart Completion System

The completion system provides intelligent suggestions at every step:

### Command Completion

Press `<space>` or `<tab>` after `:J` to see available commands:

```vim
:J <space>    " Shows: abandon, absorb, bookmark, commit, diff, log, status...
:J s<tab>     " Shows: show, squash, status...
:J lo<tab>    " Completes to: log
```

### Flag Completion

After entering a command, completion shows relevant flags:

```vim
:J status <space>     " Shows: --help, --repository, --at-operation...
:J commit --<tab>     " Shows: --message, --author, --help...
:J log --<tab>        " Shows: --template, --revisions, --limit...
```

### Value Completion

For certain flags, context-aware completions are provided:

```vim
:J log --bookmark <space>     " Shows available bookmarks: main, feature-x...
:J diff <space>               " Shows changed files for diff
:J show --revision <space>    " Shows revision suggestions
```

### Smart Filtering

The completion system intelligently filters suggestions:

- **Already-used flags** are excluded from completion
- **Empty arglead** (after space) shows all available options
- **Partial matches** filter results as you type
- **Results are sorted** alphabetically for easy scanning

## Special Integrations

### Status Buffer Refresh

Commands that change repository state automatically refresh any open status buffers:

```vim
:J commit -m "Changes"    " Status buffer updates automatically
:J new                    " Status buffer shows new working copy
:J edit abc123            " Status buffer reflects new working copy
```

### Custom Command Handling

Some commands receive special treatment:

- `:J status` → Opens interactive status buffer (`:JStatus`)
- `:J diff [file]` → Opens enhanced diff viewer (`:JDiff`)
- `:J log` (without args) → Uses custom log display

All other commands pass through directly to jj with full argument support.

## Advanced Features

### Caching

The completion system caches help output for 5 minutes to improve performance:

- Command lists from `jj --help`
- Flag lists from `jj <command> --help`
- Cache automatically expires and refreshes

### Error Handling

- Invalid commands show jj's native error messages
- Failed operations display clear error feedback
- Completion gracefully handles missing jj installation

## Examples

### Daily Workflow

```vim
" Check status
:J

" View recent changes
:J log -r @- -T compact

" Create a commit
:J commit -m "Implement new feature"

" Start working on something new
:J new -m "Begin refactoring"

" Check what changed
:J diff

" Set a bookmark
:J bookmark set feature-complete
```

### Advanced Operations

```vim
" Interactive rebase-like operations
:J squash -r @--       " Squash last two changes
:J split               " Split current change
:J rebase -d main      " Rebase onto main

" Branch management
:J bookmark list
:J bookmark set my-feature
:J bookmark delete old-feature

" Complex queries
:J log -r 'author("me") & description(glob:"feat*")'
:J log -T 'commit_id ++ " " ++ description.first_line()' -r main..@
```

### Integration with Neovim

```vim
" Open status in split
:vsplit | J

" Quick commit current buffer
:w | J commit -m "Update documentation"

" View diff before committing
:J diff | split | J status
```

## Configuration

Currently, the `:J` command works out of the box with no configuration needed. Future versions may add:

- Custom command aliases
- Default argument templates
- Completion behavior customization
- Integration with other plugins

## Troubleshooting

### Command Not Found

If `:J` shows "command not found":

1. Ensure jj is installed: `jj --version`
2. Check PATH includes jj: `:echo $PATH`
3. Restart Neovim after installing jj

### Completion Not Working

If tab completion doesn't work:

1. Verify you're in a jj repository
2. Check jj responds to `--help`: `jj --help`
3. Try clearing completion cache (restart Neovim)

### Slow Completion

If completion is slow:

- Completion uses 5-minute caching by default
- First use may be slower while parsing help output
- Subsequent uses should be fast

## See Also

- [JStatus Documentation](jstatus.md) - Interactive status buffer
- [JDiff Documentation](jdiff.md) - Enhanced diff viewer
- [Development Guide](development.md) - Plugin development info