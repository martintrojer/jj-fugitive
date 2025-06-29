# jj-fugitive Test Suite

This directory contains comprehensive tests for the jj-fugitive Neovim plugin.

## Test Categories

### Core Functionality Tests
- **`test_status_functionality.lua`** - Tests basic status view functionality
- **`test_diff_functionality.lua`** - Tests diff view functionality 
- **`test_completion_functionality.lua`** - Tests command completion
- **`test_log_functionality.lua`** - Tests basic log view functionality

### Enhanced Feature Tests
- **`test_status_features.lua`** - Tests enhanced status features (cursor positioning, buffer management)
- **`test_repository_detection.lua`** - Tests repository root detection from subdirectories ⭐
- **`test_log_enter_functionality.lua`** - Tests log view Enter key functionality ⭐
- **`test_user_experience_simulation.lua`** - End-to-end user workflow simulation ⭐

### Demo and Manual Tests
- **`demo_enhanced_diff.lua`** - Interactive demo of enhanced diff features
- **`demo_log_view.lua`** - Interactive demo of enhanced log view
- **`manual_test.lua`** - Manual testing utilities
- **`test_enhanced_diff.txt`** - Sample diff output for testing

## Key Tests (⭐ = Addresses Original Reported Issues)

### Repository Detection (`test_repository_detection.lua`)
**Addresses:** "There is no jj repo in '.' - This looks like a git repo" error

Tests:
- Repository root detection from current directory
- Repository root detection from subdirectories  
- Repository root detection from nested subdirectories
- Path consistency across different starting directories
- jj command execution from various directories

### Log Enter Functionality (`test_log_enter_functionality.lua`)  
**Addresses:** Pressing Enter in log view giving errors

Tests:
- Log buffer creation and formatting
- Cursor positioning on valid commit lines
- Commit ID extraction from formatted lines
- jj show command execution with extracted commit IDs
- Functionality from subdirectories
- Multiple commit line validation

### User Experience Simulation (`test_user_experience_simulation.lua`)
**Addresses:** Complete user workflow verification

Simulates:
1. User runs `:J log`
2. Log view opens with proper formatting
3. Cursor positioned on first commit
4. User presses Enter
5. Commit details displayed successfully
6. All operations work from subdirectories

## Running Tests

### Run All Tests
```bash
./tests/run_tests.sh
```

### Run Individual Tests
```bash
./tests/test_repository_detection.lua
./tests/test_log_enter_functionality.lua
./tests/test_user_experience_simulation.lua
```

### Run Key Tests Only
```bash
# Test the original reported issues
./tests/test_repository_detection.lua
./tests/test_log_enter_functionality.lua
```

## Test Requirements

- Must be run from within a jj repository
- Neovim must be available in PATH
- jj command must be available and working

## Expected Results

All tests should pass with `🎉 All tests passed!` messages. Any failures indicate regressions that need to be addressed.

## Adding New Tests

When adding new functionality:
1. Create test file in `tests/` directory
2. Make it executable: `chmod +x tests/new_test.lua`
3. Add to `run_tests.sh` if it should be part of the standard test suite
4. Follow the existing test pattern with assert_test() function
5. Update this README with test description