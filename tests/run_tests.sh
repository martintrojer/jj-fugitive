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
echo ""

# Discover and run all test files
test_count=0
passed_count=0
failed_tests=()

# Find all executable test files (excluding manual tests and demos)
echo "📋 Discovering test files..."
test_files=()
while IFS= read -r -d '' file; do
    # Skip manual tests, demos, and non-executable files
    if [[ "$file" == *"manual_test"* ]] || [[ "$file" == *"demo_"* ]]; then
        echo "⏭️  Skipping: $(basename "$file") (manual/demo)"
        continue
    fi
    
    # Check if file is executable
    if [[ -x "$file" ]]; then
        test_files+=("$file")
        echo "✓ Found: $(basename "$file")"
    else
        echo "⚠️  Found non-executable: $(basename "$file")"
        # Make it executable
        chmod +x "$file"
        test_files+=("$file")
        echo "✓ Made executable: $(basename "$file")"
    fi
done < <(find tests/ -name "test_*.lua" -print0 | sort -z)

echo ""
echo "🎯 Found ${#test_files[@]} test files to run"
echo ""

# Run each test file
for test_file in "${test_files[@]}"; do
    test_name=$(basename "$test_file" .lua)
    echo "🧪 Running: $test_name"
    echo "   File: $test_file"
    
    ((test_count++))
    
    # Run the test and capture output
    if "$test_file" > /tmp/test_output_$$.log 2>&1; then
        echo "   ✅ PASSED"
        ((passed_count++))
        # Show brief success message from test output
        if grep -q "All.*tests passed" /tmp/test_output_$$.log; then
            grep "All.*tests passed" /tmp/test_output_$$.log | head -1 | sed 's/^/   🎉 /'
        fi
    else
        echo "   ❌ FAILED"
        failed_tests+=("$test_name")
        echo "   📄 Error output:"
        sed 's/^/      /' /tmp/test_output_$$.log
    fi
    
    # Clean up temp file
    rm -f /tmp/test_output_$$.log
    echo ""
done

# Run demo files if they exist (non-failing)
echo "🎭 Running demo files (non-critical)..."
demo_files=()
while IFS= read -r -d '' file; do
    demo_files+=("$file")
done < <(find tests/ -name "demo_*.lua" -print0 2>/dev/null | sort -z)

if [[ ${#demo_files[@]} -gt 0 ]]; then
    for demo_file in "${demo_files[@]}"; do
        if [[ -x "$demo_file" ]]; then
            demo_name=$(basename "$demo_file" .lua)
            echo "🎪 Running demo: $demo_name"
            if "$demo_file" > /tmp/demo_output_$$.log 2>&1; then
                echo "   ✅ Demo completed successfully"
            else
                echo "   ⚠️  Demo had issues (non-critical)"
            fi
            rm -f /tmp/demo_output_$$.log
        fi
    done
else
    echo "   No demo files found"
fi
echo ""

# Print summary
echo "📊 === Test Results Summary ==="
echo "Total tests run: $test_count"
echo "Passed: $passed_count"
echo "Failed: $((test_count - passed_count))"
echo ""

if [[ $passed_count -eq $test_count ]]; then
    echo "🎉 All tests passed!"
    echo "✨ jj-fugitive is working correctly"
else
    echo "💥 Some tests failed:"
    for failed_test in "${failed_tests[@]}"; do
        echo "   ❌ $failed_test"
    done
    echo ""
    echo "Please check the failed tests above."
    exit 1
fi

echo "🎉 All tests completed!"