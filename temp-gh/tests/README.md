# jj-fugitive Test Suite

This directory contains comprehensive tests for the jj-fugitive Neovim plugin. The test suite uses intelligent discovery to automatically find and run all test files.

## Test Runner

### Quick Start
```bash
# Run all tests with intelligent discovery
./tests/run_tests.sh

# Run a specific test
./tests/test_status_functionality.lua

# Run all tests matching a pattern
./tests/test_log*.lua
```

### Features
- **Intelligent Discovery**: Automatically finds all `test_*.lua` files
- **Comprehensive Coverage**: Linting, formatting, and functional tests
- **Detailed Reporting**: Shows individual test results and summary
- **Demo Support**: Runs demo files separately (non-critical)
- **Executable Management**: Automatically makes test files executable

## Test Categories

### Core Functionality Tests
- **`test_status_functionality.lua`** - Status view creation and navigation
- **`test_diff_functionality.lua`** - Diff view and file comparison features  
- **`test_log_functionality.lua`** - Log view with commit history
- **`test_completion_functionality.lua`** - Command completion system

### Native Integration Tests
- **`test_native_log_view.lua`** - Native jj log format preservation
- **`test_commit_extraction.lua`** - ANSI processing and commit ID extraction
- **`test_repository_detection.lua`** - Repository discovery from subdirectories

### Advanced Feature Tests
- **`test_status_features.lua`** - Cursor positioning and buffer management
- **`test_log_enter_functionality.lua`** - Interactive log navigation
- **`test_status_enter_l_keys.lua`** - Keyboard shortcuts and mappings
- **`test_status_keybindings_simple.lua`** - Basic keybinding functionality

### Color and Format Tests
- **`test_color_rendering.lua`** - ANSI color processing
- **`test_log_color_rendering.lua`** - Log-specific color handling
- **`test_unified_ansi_functionality.lua`** - Shared ANSI parsing module
- **`test_format_consistency.lua`** - Format consistency across views
- **`test_git_format_consistency.lua`** - Git diff format standardization

### User Experience Tests
- **`test_user_experience_simulation.lua`** - End-to-end workflow simulation
- **`test_vim_fugitive_alignment.lua`** - vim-fugitive compatibility
- **`test_improved_diff.lua`** - Enhanced diff view features
- **`test_inline_help.lua`** - Help system functionality
- **`test_inline_help_simple.lua`** - Basic help features

### Documentation and Quality Tests
- **`test_documentation.lua`** - Documentation completeness and accuracy

## Test Architecture

### Test File Structure
```lua
#!/usr/bin/env -S nvim --headless -l

-- Test description
vim.cmd("set rtp+=.")
vim.cmd("runtime plugin/jj-fugitive.lua")

local test_results = {}
local function assert_test(name, condition, message)
  -- Test assertion logic
end

-- Test implementation
-- ...

-- Summary and exit
```

### Key Components

#### Test Discovery
The test runner automatically discovers test files using:
```bash
find tests/ -name "test_*.lua" -print0 | sort -z
```

#### Test Execution
- Each test runs in isolation with captured output
- Failed tests show detailed error information
- Summary provides pass/fail counts and specific failures

#### Test Types
- **Unit Tests**: Individual component testing
- **Integration Tests**: Cross-component functionality
- **End-to-End Tests**: Complete workflow validation
- **Regression Tests**: Prevention of known issues

## Running Tests

### Prerequisites
```bash
# Required tools
brew install luacheck     # Lua linting
brew install stylua       # Lua formatting
# jj CLI tool must be available in PATH
```

### Environment
- Tests must run from within a jj repository
- Neovim must support headless mode with Lua
- Tests create temporary files (automatically cleaned up)

### Test Patterns

#### Basic Test
```lua
assert_test("Feature works", some_condition, "Error message if failed")
```

#### Module Loading
```lua
local module = require("jj-fugitive.module")
assert_test("Module loads", module ~= nil, "Could not require module")
```

#### Buffer Testing
```lua
local bufnr = vim.api.nvim_create_buf(false, true)
assert_test("Buffer created", bufnr ~= nil, "Buffer creation failed")
```

#### Command Testing
```lua
local result = vim.fn.system({"jj", "status"})
assert_test("Command works", vim.v.shell_error == 0, "Command failed")
```

## Test Results

The test runner provides detailed results:

```
📊 === Test Results Summary ===
Total tests run: 22
Passed: 16
Failed: 6

💥 Some tests failed:
   ❌ test_format_consistency
   ❌ test_git_format_consistency
```

### Success Indicators
- ✅ **All tests passed**: Full functionality verified
- 🎉 **Specific achievements**: Individual test accomplishments
- 📝 **Key achievements**: Summary of validated features

### Failure Analysis
- 📄 **Error output**: Detailed failure information
- ❌ **Failed test name**: Specific test that failed
- 💥 **Failure summary**: Overview of issues

## Continuous Integration

The test suite is designed for CI environments:

```bash
# CI-friendly execution
./tests/run_tests.sh
exit_code=$?

if [ $exit_code -eq 0 ]; then
    echo "All tests passed - ready for merge"
else
    echo "Tests failed - review required"
    exit $exit_code
fi
```

## Demo Files

Demo files showcase functionality but don't affect test results:
- **`demo_enhanced_diff.lua`** - Diff view demonstration
- **`demo_log_view.lua`** - Log view demonstration

## Manual Testing

For interactive testing:
- **`manual_test.lua`** - Manual testing helpers (excluded from automated runs)

## Best Practices

### Writing Tests
1. **Clear Names**: Use descriptive test names
2. **Isolated Tests**: Each test should be independent
3. **Comprehensive Coverage**: Test both success and failure cases
4. **Clean Up**: Remove temporary files and state
5. **Meaningful Messages**: Provide helpful error messages

### Test Organization
1. **Group Related Tests**: Keep similar functionality together
2. **Progressive Complexity**: Start with basic tests, build up
3. **Document Assumptions**: Note any test prerequisites
4. **Version Compatibility**: Consider different jj/Neovim versions

### Debugging Tests
1. **Run Individual Tests**: Test specific functionality
2. **Add Debug Output**: Use print statements for investigation
3. **Check Prerequisites**: Ensure jj repository and tools available
4. **Review Error Output**: Analyze detailed failure information

## Contributing

When adding new tests:

1. Follow the naming convention: `test_*.lua`
2. Make the file executable: `chmod +x tests/test_new_feature.lua`
3. Include in appropriate category above
4. Test both success and failure cases
5. Add to this documentation

The intelligent test discovery will automatically include new test files in the next run.