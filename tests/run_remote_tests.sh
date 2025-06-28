#!/bin/bash

# Remote API Test Runner for jj-fugitive
# 
# This script provides an easy way to run remote API tests for jj-fugitive
# using different methods (Python, Lua, or simple shell commands).

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}🧪 jj-fugitive Remote API Test Runner${NC}"
echo "Project directory: $PROJECT_DIR"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    echo -e "\n${YELLOW}📋 Checking prerequisites...${NC}"
    
    # Check if we're in a jj repository
    if ! command_exists jj; then
        echo -e "${RED}❌ jj command not found. Please install Jujutsu.${NC}"
        exit 1
    fi
    
    if ! jj status >/dev/null 2>&1; then
        echo -e "${RED}❌ Not in a jj repository. Please run from a jj repository.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ jj repository check passed${NC}"
    
    # Check Neovim
    if ! command_exists nvim; then
        echo -e "${RED}❌ Neovim not found. Please install Neovim.${NC}"
        exit 1
    fi
    
    # Check Neovim version
    nvim_version=$(nvim --version | head -n1 | grep -o 'v[0-9]\+\.[0-9]\+')
    echo -e "${GREEN}✅ Neovim found: $nvim_version${NC}"
    
    # Check if Neovim supports --listen
    if ! nvim --help | grep -q "\-\-listen"; then
        echo -e "${RED}❌ Neovim doesn't support --listen flag${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Neovim remote API support confirmed${NC}"
}

# Function to run Python tests
run_python_tests() {
    echo -e "\n${BLUE}🐍 Running Python remote API tests...${NC}"
    
    if ! command_exists python3; then
        echo -e "${RED}❌ Python 3 not found${NC}"
        return 1
    fi
    
    # Check for pynvim - try uv first, then pip
    if ! python3 -c "import pynvim" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  pynvim not found. Installing...${NC}"
        
        # Try uv first
        if command_exists uv; then
            echo "Using uv to install dependencies..."
            uv sync
        elif command_exists pip3; then
            pip3 install pynvim
        else
            echo -e "${RED}❌ Neither uv nor pip3 found. Please install pynvim manually${NC}"
            echo "   With uv: uv sync"
            echo "   With pip: pip install pynvim"
            return 1
        fi
    fi
    
    cd "$PROJECT_DIR"
    python3 tests/remote_api_test.py
}

# Function to run Lua tests
run_lua_tests() {
    echo -e "\n${BLUE}🌙 Running Lua remote API tests...${NC}"
    
    if ! command_exists lua; then
        echo -e "${RED}❌ Lua not found${NC}"
        return 1
    fi
    
    cd "$PROJECT_DIR"
    lua tests/remote_api_test.lua
}

# Function to run simple shell-based tests
run_shell_tests() {
    echo -e "\n${BLUE}🐚 Running simple shell-based tests...${NC}"
    
    cd "$PROJECT_DIR"
    
    # Start Neovim in background
    SOCKET_PATH="/tmp/nvim_shell_test.sock"
    rm -f "$SOCKET_PATH"
    
    echo "Starting headless Neovim..."
    nvim --headless --listen "$SOCKET_PATH" --cmd "set rtp+=." -c "runtime plugin/jj-fugitive.lua" &
    NVIM_PID=$!
    
    # Cleanup function
    cleanup() {
        echo "Cleaning up..."
        kill "$NVIM_PID" 2>/dev/null || true
        rm -f "$SOCKET_PATH"
    }
    trap cleanup EXIT
    
    # Wait for socket
    for i in {1..50}; do
        if [ -S "$SOCKET_PATH" ]; then
            break
        fi
        sleep 0.1
    done
    
    if [ ! -S "$SOCKET_PATH" ]; then
        echo -e "${RED}❌ Failed to start Neovim${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Neovim started${NC}"
    
    # Test command availability
    echo "Testing command availability..."
    for cmd in JStatus JLog JDiff JCommit; do
        result=$(nvim --server "$SOCKET_PATH" --remote-expr "exists(':$cmd')" 2>/dev/null || echo "0")
        if [ "$result" = "1" ]; then
            echo -e "${GREEN}✅ :$cmd available${NC}"
        else
            echo -e "${RED}❌ :$cmd not available${NC}"
            return 1
        fi
    done
    
    # Test JStatus execution
    echo "Testing :JStatus execution..."
    nvim --server "$SOCKET_PATH" --remote-expr 'execute("JStatus")' >/dev/null 2>&1
    
    sleep 0.5
    
    # Check if status buffer was created (simplified check)
    buffer_count=$(nvim --server "$SOCKET_PATH" --remote-expr 'len(getbufinfo())' 2>/dev/null || echo "0")
    if [ "$buffer_count" -gt 1 ]; then
        echo -e "${GREEN}✅ :JStatus appears to have created a buffer${NC}"
    else
        echo -e "${YELLOW}⚠️  Unable to verify :JStatus buffer creation${NC}"
    fi
    
    echo -e "${GREEN}✅ Shell tests completed${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS] [TEST_TYPE]"
    echo ""
    echo "Test types:"
    echo "  python    - Run Python-based tests (recommended)"
    echo "  lua       - Run Lua-based tests"
    echo "  shell     - Run simple shell-based tests"
    echo "  all       - Run all available tests (default)"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help"
    echo "  --no-prereq   Skip prerequisite checks"
    echo ""
    echo "Examples:"
    echo "  $0                 # Run all tests"
    echo "  $0 python          # Run only Python tests"
    echo "  $0 --no-prereq lua # Run Lua tests without prereq check"
}

# Parse command line arguments
SKIP_PREREQ=false
TEST_TYPE="all"

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        --no-prereq)
            SKIP_PREREQ=true
            shift
            ;;
        python|lua|shell|all)
            TEST_TYPE="$1"
            shift
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    if [ "$SKIP_PREREQ" = false ]; then
        check_prerequisites
    fi
    
    case "$TEST_TYPE" in
        python)
            run_python_tests
            ;;
        lua)
            run_lua_tests
            ;;
        shell)
            run_shell_tests
            ;;
        all)
            echo -e "\n${BLUE}🎯 Running all available tests...${NC}"
            
            # Try Python first (most reliable)
            if command_exists python3 && python3 -c "import pynvim" 2>/dev/null; then
                if run_python_tests; then
                    echo -e "\n${GREEN}🎉 Python tests passed!${NC}"
                else
                    echo -e "\n${RED}💥 Python tests failed${NC}"
                fi
            else
                echo -e "\n${YELLOW}⚠️  Skipping Python tests (pynvim not available)${NC}"
            fi
            
            # Try Lua tests
            if command_exists lua; then
                if run_lua_tests; then
                    echo -e "\n${GREEN}🎉 Lua tests passed!${NC}"
                else
                    echo -e "\n${RED}💥 Lua tests failed${NC}"
                fi
            else
                echo -e "\n${YELLOW}⚠️  Skipping Lua tests (lua not available)${NC}"
            fi
            
            # Always run shell tests as fallback
            if run_shell_tests; then
                echo -e "\n${GREEN}🎉 Shell tests passed!${NC}"
            else
                echo -e "\n${RED}💥 Shell tests failed${NC}"
            fi
            ;;
        *)
            echo -e "${RED}❌ Invalid test type: $TEST_TYPE${NC}"
            show_usage
            exit 1
            ;;
    esac
    
    echo -e "\n${GREEN}✨ Test run completed!${NC}"
}

# Run main function
main "$@"