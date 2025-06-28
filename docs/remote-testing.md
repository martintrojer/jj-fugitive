# Remote API Testing

This document describes how to test jj-fugitive using Neovim's remote API, allowing automated testing without manual Neovim interaction.

## Overview

The remote API testing system allows you to:
- Start headless Neovim instances with the plugin loaded
- Execute commands and test functionality programmatically  
- Validate plugin behavior without GUI interaction
- Run tests in CI/CD environments

## Available Test Methods

### 1. Python Tests (Recommended)

Uses `pynvim` library for robust RPC communication.

**Prerequisites:**
```bash
# With uv (recommended)
uv sync

# Or with pip
pip install pynvim
```

**Run Python tests:**
```bash
# With uv
uv run python tests/remote_api_test.py

# Or directly
python3 tests/remote_api_test.py
```

**Features:**
- Full RPC API access
- Buffer inspection and manipulation
- Comprehensive error handling
- Detailed test output

### 2. Lua Tests

Pure Lua implementation using shell commands and Neovim's `--remote` flags.

**Run Lua tests:**
```bash
lua tests/remote_api_test.lua
```

**Features:**
- No external dependencies
- Cross-platform compatibility
- Simple shell-based communication

### 3. Shell Tests

Bash script using basic Neovim remote commands.

**Run shell tests:**
```bash
./tests/run_remote_tests.sh shell
```

**Features:**
- Minimal dependencies
- Quick validation
- Good for CI environments

### 4. All Tests Runner

Comprehensive test runner that tries all methods.

**Run all tests:**
```bash
./tests/run_remote_tests.sh
```

## Test Architecture

### Neovim Instance Management

All test methods follow this pattern:

1. **Start headless Neovim:**
   ```bash
   nvim --headless --listen /tmp/socket --cmd "set rtp+=." -c "runtime plugin/jj-fugitive.lua"
   ```

2. **Connect via RPC:**
   - Python: Uses `pynvim.attach('socket', path='/tmp/socket')`
   - Lua/Shell: Uses `nvim --server /tmp/socket --remote-expr`

3. **Execute tests:**
   - Command availability checks
   - Plugin functionality tests
   - Buffer creation validation

4. **Cleanup:**
   - Graceful Neovim shutdown
   - Socket cleanup
   - Process termination

### Test Categories

#### Plugin Loading Tests
- Verify jj-fugitive commands are registered
- Check command availability (`:JStatus`, `:JLog`, etc.)
- Validate plugin initialization

#### Functionality Tests
- Execute `:JStatus` command
- Verify status buffer creation
- Check buffer properties (buftype, modifiable, etc.)
- Validate buffer content

#### Integration Tests
- Test in actual jj repositories
- Verify jj command integration
- Check file change detection

## Example: Python API Usage

```python
import pynvim

# Connect to running Neovim instance
nvim = pynvim.attach('socket', path='/tmp/nvim_socket')

# Execute plugin command
nvim.command('JStatus')

# Find status buffer
for buf in nvim.buffers:
    if 'jj-status' in buf.name:
        # Get buffer contents
        lines = buf[:]
        content = '\n'.join(lines)
        
        # Validate content
        assert 'jj-fugitive Status' in content
        break

# Cleanup
nvim.command('qall!')
```

## Manual Testing Methods

For interactive development and debugging, you can load the plugin directly in Neovim:

### Method 1: Using vim.opt.rtp (Quick Testing)

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

### Method 2: Temporary Plugin Manager Setup

Create a minimal init file for testing:

```lua
-- test_init.lua
vim.opt.rtp:prepend("/path/to/jj-fugitive")
require("jj-fugitive")
```

```bash
nvim -u test_init.lua
```

### Method 3: Using Package Manager in Dev Mode

For lazy.nvim:
```lua
{
  dir = "/path/to/jj-fugitive",  -- Use local directory
  name = "jj-fugitive",
  dev = true,
}
```

### Testing in a jj Repository

```bash
# Create a test jj repository
mkdir test-repo && cd test-repo
jj init --git
echo "test content" > file.txt
jj describe -m "Initial commit"

# Open Neovim and test commands
nvim --cmd "set rtp+=../jj-fugitive"
```

## Writing New Tests

### Adding Python Tests

Add test methods to `JJFugitiveAPITest` class:

```python
def test_new_feature(self):
    """Test description"""
    print("\n=== Testing new feature ===")
    
    try:
        # Execute command
        self.nvim.command('JNewCommand')
        
        # Validate results
        result = self.nvim.eval('some_check()')
        
        if result:
            print("✅ PASS: New feature works")
            return True
        else:
            print("❌ FAIL: New feature failed")
            return False
            
    except Exception as e:
        print(f"❌ FAIL: Error: {e}")
        return False
```

### Adding Shell Tests

Add functions to `run_remote_tests.sh`:

```bash
test_new_feature() {
    echo "Testing new feature..."
    
    result=$(nvim --server "$SOCKET_PATH" --remote-expr 'execute("JNewCommand")' 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo "✅ New feature test passed"
        return 0
    else
        echo "❌ New feature test failed"
        return 1
    fi
}
```

## CI Integration

### GitHub Actions

```yaml
- name: Test jj-fugitive remote API
  run: |
    # Install dependencies
    uv sync
    
    # Run tests
    ./tests/run_remote_tests.sh python
```

### Prerequisites for CI

1. **Neovim installation** with `--headless` and `--listen` support
2. **Python environment** with pynvim (use uv for dependency management)
3. **jj repository** (tests require a valid jj repo)
4. **Display environment** (set `DISPLAY=:99` for headless)

## Debugging Remote Tests

### Common Issues

**Socket creation fails:**
- Check Neovim version supports `--listen`
- Verify socket path permissions
- Ensure no conflicting processes

**Plugin not loaded:**
- Verify runtime path includes plugin directory
- Check plugin file syntax
- Validate command registration

**Buffer tests fail:**
- Confirm buffer creation timing
- Check buffer name patterns
- Verify buffer properties

### Debug Commands

```bash
# Check Neovim remote capabilities
nvim --help | grep -E "(listen|remote)"

# Test socket creation
nvim --headless --listen /tmp/test.sock &
sleep 1
[ -S /tmp/test.sock ] && echo "Socket created" || echo "Socket failed"

# Test command availability
nvim --server /tmp/test.sock --remote-expr "exists(':JStatus')"
```

## Performance Considerations

- **Startup time:** Headless Neovim starts in ~100-200ms
- **Test execution:** Python tests are fastest (~1-2s total)
- **Memory usage:** Minimal overhead for headless instances
- **Parallel testing:** Each test uses separate socket/process

## Limitations

- **No GUI testing:** Cannot test visual aspects
- **Limited user interaction:** No keyboard/mouse simulation
- **Platform differences:** Some features may behave differently headless
- **Timing sensitivity:** Buffer creation may need wait periods

## Future Enhancements

- **Automated CI integration** in GitHub Actions
- **Performance benchmarking** with remote API
- **Mock jj repository** creation for isolated testing
- **Buffer content validation** with regex patterns
- **Keybinding testing** via remote key sending

## Troubleshooting

### Test Failures

1. **Check prerequisites:** Ensure Neovim, jj, and Python deps are available
2. **Verify jj repo:** Tests must run in a valid jj repository
3. **Debug output:** Use verbose flags for detailed error information
4. **Manual verification:** Test commands manually in Neovim

### Clean Up Issues

If tests leave processes running:

```bash
# Kill all test Neovim instances
pkill -f "nvim.*headless.*jj_fugitive"

# Remove test sockets
rm -f /tmp/nvim_*_test.sock
```

---

*This testing approach provides comprehensive validation of jj-fugitive functionality without requiring manual Neovim interaction, enabling automated testing and CI integration.*