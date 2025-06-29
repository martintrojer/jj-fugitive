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

# Test completion functionality
echo "Testing completion functionality..."
./tests/test_completion_functionality.lua

echo ""

# Test status features (cursor positioning and buffer switching)
echo "Testing status features..."
./tests/test_status_features.lua

echo ""

# Demo enhanced diff view (if demo file exists)
if [ -f "./tests/demo_enhanced_diff.lua" ]; then
  echo "Running enhanced diff demo..."
  ./tests/demo_enhanced_diff.lua
  echo ""
fi

echo "🎉 All tests completed!"