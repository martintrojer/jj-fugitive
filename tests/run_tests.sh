#!/bin/bash
set -e

echo "🚀 === jj-fugitive Test Suite ==="
echo ""

# Check if we're in a jj repository
if ! jj status >/dev/null 2>&1; then
    echo "❌ Error: Not in a jj repository"
    echo "Please run tests from a jj repository directory"
    exit 1
fi

echo "✅ Running in jj repository"
echo ""

# Run Lua linting
echo "📝 Running Lua linting..."
if command -v luacheck >/dev/null 2>&1; then
    luacheck .
    echo "✅ Lua linting passed"
else
    echo "⚠️  luacheck not found, skipping Lua linting"
fi
echo ""

# Run Lua formatting check
echo "🎨 Checking Lua formatting..."
if command -v stylua >/dev/null 2>&1; then
    stylua --check .
    echo "✅ Lua formatting check passed"
else
    echo "⚠️  stylua not found, skipping Lua formatting check"
fi
echo ""

# Run unit tests (if they exist)
if [ -f "tests/minimal_init.lua" ] && command -v plenary >/dev/null 2>&1; then
    echo "🧪 Running unit tests..."
    export PLENARY_DIR=${PLENARY_DIR:-/tmp/plenary.nvim}
    if [ ! -d "$PLENARY_DIR" ]; then
        echo "📦 Cloning plenary.nvim..."
        git clone https://github.com/nvim-lua/plenary.nvim "$PLENARY_DIR"
    fi
    nvim --headless --noplugin -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"
    echo ""
fi

# Run functional tests
echo "🔧 Running functional tests..."

# Test status functionality
echo "Testing status functionality..."
./tests/test_status_functionality.lua

echo ""

# Test diff functionality  
echo "Testing diff functionality..."
./tests/test_diff_functionality.lua

echo ""

echo "🎉 All tests completed!"