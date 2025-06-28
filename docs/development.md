# Development Guide

This guide covers how to set up, test, and contribute to jj-fugitive development.

## Prerequisites

- Neovim 0.8+
- [Jujutsu (jj)](https://github.com/martinvonz/jj) installed and in PATH
- Lua development tools (luacheck, stylua)
- Git for version control integration

## Setting Up Development Environment

### Clone and Setup

```bash
git clone https://github.com/username/jj-fugitive.nvim.git
cd jj-fugitive.nvim

# Install development dependencies
luarocks install luacheck
luarocks install busted
```

### Install Development Tools

```bash
# Install stylua for formatting
brew install stylua  # macOS
# or
cargo install stylua  # Cross-platform

# Install luacheck for linting  
brew install luacheck  # macOS
# or
luarocks install luacheck  # Cross-platform
```

## Testing

### Running Tests

```bash
# Install test dependencies
git clone https://github.com/nvim-lua/plenary.nvim /tmp/plenary.nvim

# Run all tests
export PLENARY_DIR=/tmp/plenary.nvim
nvim --headless --noplugin -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"
```

### Writing Tests

Tests are located in the `tests/` directory and use the busted framework with plenary.nvim:

```lua
-- tests/example_spec.lua
local module = require("jj-fugitive.module")

describe("module functionality", function()
  it("should do something", function()
    assert.is_not_nil(module)
    assert.is_function(module.some_function)
  end)
end)
```

### Testing the Plugin in Neovim

#### Method 1: Using vim.opt.rtp (Quick Testing)

```bash
# Navigate to your plugin directory
cd /path/to/jj-fugitive

# Start Neovim with the plugin in runtime path
nvim --cmd "set rtp+=."
```

Then in Neovim:
```vim
" Source the plugin manually
:runtime plugin/jj-fugitive.lua

" Test commands
:JStatus
:JLog
```

#### Method 2: Temporary Plugin Manager Setup

Create a minimal init file for testing:

```lua
-- test_init.lua
vim.opt.rtp:prepend("/path/to/jj-fugitive")
require("jj-fugitive")
```

```bash
nvim -u test_init.lua
```

#### Method 3: Using Package Manager in Dev Mode

For lazy.nvim:
```lua
{
  dir = "/path/to/jj-fugitive",  -- Use local directory
  name = "jj-fugitive",
  dev = true,
}
```

#### Testing in a jj Repository

```bash
# Create a test jj repository
mkdir test-repo && cd test-repo
jj init --git
echo "test content" > file.txt
jj describe -m "Initial commit"

# Open Neovim and test commands
nvim --cmd "set rtp+=../jj-fugitive"
```

## Code Quality

### Linting

```bash
# Run linting (configured to only check our code, not dependencies)
luacheck .

# Fix common issues automatically
luacheck . --fix
```

Configuration is in `.luacheckrc` and excludes external dependencies.

### Formatting

```bash
# Format all Lua files
stylua .

# Check formatting without changing files
stylua --check .
```

Configuration is in `stylua.toml`.

### Pre-commit Checks

Before committing, run:

```bash
# Run all checks
luacheck .
stylua --check .
export PLENARY_DIR=/tmp/plenary.nvim && nvim --headless --noplugin -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"
```

## Architecture

### Project Structure

```
jj-fugitive.nvim/
├── lua/jj-fugitive/
│   ├── init.lua           # Main plugin entry point
│   ├── status.lua         # :JStatus implementation
│   └── ...                # Other modules
├── plugin/
│   └── jj-fugitive.lua    # Command registration
├── tests/
│   ├── minimal_init.lua   # Test setup
│   └── *_spec.lua         # Test files
├── docs/                  # Documentation
└── README.md
```

### Module Organization

- **`lua/jj-fugitive/init.lua`** - Main plugin interface and command handlers
- **`lua/jj-fugitive/status.lua`** - Status buffer implementation
- **`plugin/jj-fugitive.lua`** - Neovim command registration

### Adding New Features

1. Create a new module in `lua/jj-fugitive/`
2. Add command registration in `plugin/jj-fugitive.lua`
3. Write tests in `tests/`
4. Add documentation in `docs/`

Example new module:

```lua
-- lua/jj-fugitive/newfeature.lua
local M = {}

function M.do_something()
  -- Implementation
end

return M
```

## Contributing

### Workflow

1. **Fork** the repository
2. **Create feature branch**: `git checkout -b feature/awesome-feature`
3. **Make changes** following the coding standards
4. **Run tests** and ensure they pass
5. **Run linting and formatting**
6. **Commit changes** with descriptive messages
7. **Push to fork** and create a pull request

### Commit Messages

Use conventional commit format:

```
feat: add interactive log browser
fix: resolve status buffer refresh issue
docs: update installation instructions
test: add status buffer integration tests
```

### Code Style

- Follow existing Lua patterns in the codebase
- Use 2-space indentation (configured in stylua.toml)
- Prefer explicit returns and clear function names
- Add comments for complex logic
- Use vim-style APIs consistently

### Pull Request Guidelines

1. **Description**: Clearly describe what the PR does
2. **Tests**: Include tests for new functionality
3. **Documentation**: Update docs for user-facing changes
4. **Backwards compatibility**: Avoid breaking changes when possible
5. **Performance**: Consider impact on startup time and responsiveness

## Debugging

### Plugin Loading Issues

```vim
" Check if plugin loaded
:echo exists('g:loaded_jj_fugitive')

" Debug command registration
:command J

" Check lua modules
:lua print(vim.inspect(package.loaded['jj-fugitive']))
```

### jj Command Issues

```vim
" Test jj command directly
:!jj status

" Check PATH
:echo $PATH

" Debug jj execution
:lua print(vim.fn.system({'jj', 'status'}))
```

### Buffer and Window Issues

```vim
" List all buffers
:ls

" Check buffer options
:setlocal

" Debug keymaps
:nmap <buffer>
```

## Release Process

1. Update version in documentation
2. Update CHANGELOG.md (when created)
3. Create git tag: `git tag v0.x.0`
4. Push tag: `git push origin v0.x.0`
5. Create GitHub release with notes

## Getting Help

- **Issues**: Use GitHub issues for bugs and feature requests
- **Discussions**: Use GitHub discussions for questions
- **Code review**: All PRs require review before merge

## Resources

- [Neovim Lua Guide](https://neovim.io/doc/user/lua-guide.html)
- [jj Documentation](https://jj-vcs.github.io/jj/)
- [vim-fugitive](https://github.com/tpope/vim-fugitive) - Inspiration and reference
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) - Testing framework