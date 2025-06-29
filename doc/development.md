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

jj-fugitive has multiple testing approaches depending on your needs:

### Unit Tests

Basic smoke tests for module loading:

```bash
# Manual smoke test
nvim tests/manual_test.lua
```

### Functional Tests

For comprehensive plugin testing using headless Neovim:

```bash
# Run all tests including linting, formatting, and functional tests
./tests/run_tests.sh

# Run individual functional tests
./tests/test_status_functionality.lua
./tests/test_diff_functionality.lua
```

### Manual Testing Methods

For interactive development and debugging:

```bash
# Test plugin loading manually
nvim --cmd 'set rtp+=.' -c 'runtime plugin/jj-fugitive.lua'

# Quick manual test
nvim tests/manual_test.lua
```

Manual testing workflow:
- Use `:JStatus` to test status functionality
- Use `:JDiff <filename>` to test diff viewer
- Test in a jj repository with actual changes
- Verify keybindings work in status buffer (r, dd, cc, etc.)

### Writing Tests

#### Unit Tests

Write simple unit tests for basic module validation:

```lua
-- tests/example_manual_test.lua
vim.cmd('set rtp+=.')
vim.cmd('runtime plugin/jj-fugitive.lua')

local module = require("jj-fugitive.module")
print("Module loaded:", module ~= nil)
print("Function exists:", type(module.some_function) == "function")
```

#### Functional Tests

Add tests using headless Neovim with Lua scripts:

```lua
#!/usr/bin/env -S nvim --headless -l

-- Test new feature
vim.cmd('set rtp+=.')
vim.cmd('runtime plugin/jj-fugitive.lua')

local function assert_test(name, condition, message)
  if condition then
    print("✅ PASS: " .. name)
  else 
    print("❌ FAIL: " .. name .. " - " .. (message or ""))
  end
end

-- Test the new feature
local module = require("jj-fugitive.new-feature")
assert_test("New feature loads", module ~= nil, "Could not load module")

-- Add more tests...
```

## Code Quality

### Lua Linting and Formatting

```bash
# Run Lua linting (configured to only check our code, not dependencies)
luacheck .

# Fix common Lua issues automatically
luacheck . --fix

# Format all Lua files
stylua .

# Check Lua formatting without changing files
stylua --check .
```

Configuration is in `.luacheckrc` (luacheck) and `stylua.toml` (stylua).

### Pre-commit Checks

Before committing, run:

```bash
# Run all Lua checks
luacheck .
stylua --check .

# Run manual smoke tests (optional)
nvim tests/manual_test.lua

# Run functional tests
./tests/run_tests.sh
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
├── doc/                   # Documentation (Vim help and markdown)
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
4. Add documentation in `doc/`

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
- [Headless Neovim testing](https://neovim.io/doc/user/starting.html#--headless) - For automated functional tests