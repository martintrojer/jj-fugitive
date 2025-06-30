#!/bin/bash
set -e

# Parse command line arguments
TESTS_ONLY=false
FORCE_VERBOSE=false

for arg in "$@"; do
    case $arg in
        --tests-only)
            TESTS_ONLY=true
            ;;
        --verbose|-v)
            FORCE_VERBOSE=true
            ;;
        --help|-h)
            echo "Usage: $0 [--tests-only] [--verbose]"
            echo ""
            echo "Options:"
            echo "  --tests-only    Skip linting and formatting, run only functional tests"
            echo "  --verbose, -v   Show full test output (automatically enabled in CI)"
            echo "  --help, -h      Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0              Run full suite (linting, formatting, tests)"
            echo "  $0 --tests-only Run only functional tests (for CI)"
            echo "  $0 --verbose    Run with full output for debugging"
            exit 0
            ;;
    esac
done

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

# Skip linting and formatting if --tests-only flag is provided
if [[ "$TESTS_ONLY" == "false" ]]; then
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
else
    echo "⏭️  Skipping linting and formatting (--tests-only mode)"
    echo ""
fi


# Run functional tests
echo "🔧 Running functional tests..."
echo ""

# Check if we should use verbose output
VERBOSE_OUTPUT="false"
if [[ "${CI:-}" == "true" ]] || [[ "${GITHUB_ACTIONS:-}" == "true" ]] || [[ "$FORCE_VERBOSE" == "true" ]]; then
    VERBOSE_OUTPUT="true"
    if [[ "${CI:-}" == "true" ]] || [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
        echo "🔍 CI environment detected - enabling verbose output"
    else
        echo "🔍 Verbose mode enabled - showing full test output"
    fi
    echo ""
fi

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
    test_count=$((test_count + 1))
    
    # Run the test and capture output
    if [[ "$VERBOSE_OUTPUT" == "true" ]]; then
        # In CI mode, show all output in real-time
        echo "   🔍 Running with verbose output..."
        # Try different execution methods for CI compatibility
        
        if [[ "$test_file" == *.lua ]]; then
            echo "   🔧 Using nvim --headless -l for Lua file"
            if nvim --headless -l "$test_file"; then
                echo "   ✅ PASSED"
                passed_count=$((passed_count + 1))
            else
                exit_code=$?
                echo "   ❌ FAILED (exit code: $exit_code)"
                failed_tests+=("$test_name")
            fi
        else
            echo "   🔧 Using direct execution for non-Lua file"
            if "$test_file"; then
                echo "   ✅ PASSED"
                passed_count=$((passed_count + 1))
            else
                echo "   ❌ FAILED"
                failed_tests+=("$test_name")
            fi
        fi
    else
        # Normal mode - capture output and show only on failure
        if "$test_file" > /tmp/test_output_$$.log 2>&1; then
            echo "   ✅ PASSED"
            passed_count=$((passed_count + 1))
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
    fi
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
            if [[ "$VERBOSE_OUTPUT" == "true" ]]; then
                # In CI mode, show demo output directly
                if "$demo_file"; then
                    echo "   ✅ Demo completed successfully"
                else
                    echo "   ⚠️  Demo had issues (non-critical)"
                fi
            else
                # Normal mode - capture demo output
                if "$demo_file" > /tmp/demo_output_$$.log 2>&1; then
                    echo "   ✅ Demo completed successfully"
                else
                    echo "   ⚠️  Demo had issues (non-critical)"
                fi
                rm -f /tmp/demo_output_$$.log
            fi
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
failed_count=$((test_count - passed_count))
echo "Failed: $failed_count"
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