#!/usr/bin/env python3
# /// script
# requires-python = ">=3.8"
# dependencies = [
#     "pynvim>=0.5.0",
# ]
# ///
"""
Remote API Test for jj-fugitive (Python version)

This script tests the jj-fugitive plugin using Neovim's remote API
via the pynvim library. It provides a more robust alternative to the
Lua version with better error handling and RPC communication.

Usage:
  python3 tests/remote_api_test.py

Requirements:
  - pynvim: pip install pynvim
  - Neovim with remote API support
  - jj repository for testing
"""

import os
import sys
import time
import subprocess
import tempfile
import atexit
from pathlib import Path

try:
    import pynvim
except ImportError:
    print("Error: pynvim is required. Install with: pip install pynvim")
    sys.exit(1)


class JJFugitiveAPITest:
    def __init__(self):
        self.nvim = None
        self.socket_path = None
        self.nvim_process = None
        
    def start_neovim(self):
        """Start headless Neovim with jj-fugitive plugin loaded"""
        print("Starting headless Neovim with jj-fugitive...")
        
        # Create temporary socket
        self.socket_path = os.path.join(tempfile.gettempdir(), "nvim_jj_fugitive_test.sock")
        
        # Remove old socket if exists
        if os.path.exists(self.socket_path):
            os.remove(self.socket_path)
        
        # Get plugin directory (assuming we're in tests/ subdirectory)
        plugin_dir = Path(__file__).parent.parent.absolute()
        
        # Start Neovim
        cmd = [
            "nvim",
            "--headless",
            "--listen", self.socket_path,
            "--cmd", f"set rtp+={plugin_dir}",
            "-c", "runtime plugin/jj-fugitive.lua"
        ]
        
        self.nvim_process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        
        # Wait for socket to be created
        for _ in range(50):  # 5 second timeout
            if os.path.exists(self.socket_path):
                break
            time.sleep(0.1)
        else:
            raise RuntimeError("Failed to start Neovim or create socket")
        
        # Connect to Neovim
        self.nvim = pynvim.attach('socket', path=self.socket_path)
        print("✅ Neovim started successfully")
        
        # Register cleanup
        atexit.register(self.cleanup)
        
    def cleanup(self):
        """Clean up Neovim process and socket"""
        print("Cleaning up...")
        
        if self.nvim:
            try:
                self.nvim.command("qall!")
            except:
                pass
            self.nvim.close()
        
        if self.nvim_process:
            self.nvim_process.terminate()
            try:
                self.nvim_process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.nvim_process.kill()
        
        if self.socket_path and os.path.exists(self.socket_path):
            os.remove(self.socket_path)
    
    def test_jj_repository(self):
        """Test that we're in a valid jj repository"""
        print("\n=== Testing jj repository ===")
        
        try:
            result = subprocess.run(
                ["jj", "status"],
                capture_output=True,
                text=True,
                check=True
            )
            print("✅ PASS: In a valid jj repository")
            print(f"jj status: {result.stdout[:100]}...")
            return True
        except (subprocess.CalledProcessError, FileNotFoundError) as e:
            print(f"❌ FAIL: Not in a jj repository or jj command failed: {e}")
            return False
    
    def test_plugin_loading(self):
        """Test that jj-fugitive commands are available"""
        print("\n=== Testing plugin loading ===")
        
        commands = ["JStatus", "JLog", "JDiff", "JCommit", "JNew"]
        
        for cmd in commands:
            try:
                result = self.nvim.eval(f"exists(':{cmd}')")
                if result:
                    print(f"✅ PASS: Command :{cmd} is available")
                else:
                    print(f"❌ FAIL: Command :{cmd} is not available")
                    return False
            except Exception as e:
                print(f"❌ FAIL: Error checking command :{cmd}: {e}")
                return False
        
        return True
    
    def test_jstatus_command(self):
        """Test the :JStatus command functionality"""
        print("\n=== Testing :JStatus command ===")
        
        try:
            # Execute :JStatus command
            print("Executing :JStatus...")
            self.nvim.command("JStatus")
            
            # Give time for buffer creation
            time.sleep(0.5)
            
            # Find the jj-status buffer
            buffers = self.nvim.list_bufs()
            status_buffer = None
            
            for buf in buffers:
                try:
                    name = buf.name
                    if "jj-status" in name:
                        status_buffer = buf
                        break
                except:
                    pass
            
            if not status_buffer:
                print("❌ FAIL: Could not find jj-status buffer")
                # Debug: list all buffers
                print("Available buffers:")
                for buf in buffers:
                    try:
                        print(f"  Buffer {buf.number}: {buf.name}")
                    except:
                        print(f"  Buffer {buf.number}: <unnamed>")
                return False
            
            print(f"✅ Found jj-status buffer: {status_buffer.number}")
            
            # Get buffer contents
            lines = status_buffer[:]
            content = "\n".join(lines)
            
            print("Status buffer content:")
            print("--- START ---")
            print(content)
            print("--- END ---")
            
            # Validate content
            expected_patterns = [
                "jj-fugitive Status",
                "Working copy",
                "Commands:",
            ]
            
            for pattern in expected_patterns:
                if pattern.lower() in content.lower():
                    print(f"✅ PASS: Found expected pattern: {pattern}")
                else:
                    print(f"❌ FAIL: Missing expected pattern: {pattern}")
                    return False
            
            return True
            
        except Exception as e:
            print(f"❌ FAIL: Error during :JStatus test: {e}")
            return False
    
    def test_jstatus_buffer_options(self):
        """Test that the status buffer has correct options set"""
        print("\n=== Testing status buffer options ===")
        
        try:
            # Execute :JStatus to create buffer
            self.nvim.command("JStatus")
            time.sleep(0.5)
            
            # Find status buffer
            buffers = self.nvim.list_bufs()
            status_buffer = None
            
            for buf in buffers:
                try:
                    if "jj-status" in buf.name:
                        status_buffer = buf
                        break
                except:
                    pass
            
            if not status_buffer:
                print("❌ FAIL: Could not find status buffer")
                return False
            
            # Check buffer options
            buffer_options = {
                'buftype': 'nofile',
                'swapfile': False,
                'modifiable': False,
            }
            
            for option, expected in buffer_options.items():
                try:
                    actual = status_buffer.options[option]
                    if actual == expected:
                        print(f"✅ PASS: {option} = {actual}")
                    else:
                        print(f"❌ FAIL: {option} = {actual}, expected {expected}")
                        return False
                except Exception as e:
                    print(f"❌ FAIL: Error checking option {option}: {e}")
                    return False
            
            return True
            
        except Exception as e:
            print(f"❌ FAIL: Error during buffer options test: {e}")
            return False
    
    def run_all_tests(self):
        """Run all tests and return success status"""
        print("🚀 === jj-fugitive Remote API Tests ===")
        
        tests = [
            ("jj repository", self.test_jj_repository),
            ("plugin loading", self.test_plugin_loading),
            (":JStatus command", self.test_jstatus_command),
            ("status buffer options", self.test_jstatus_buffer_options),
        ]
        
        passed = 0
        total = len(tests)
        
        for name, test_func in tests:
            print(f"\n🔍 Running test: {name}")
            try:
                if test_func():
                    passed += 1
            except Exception as e:
                print(f"❌ FAIL: {name} - Exception: {e}")
        
        print(f"\n📊 === Test Results ===")
        print(f"Passed: {passed}/{total}")
        
        if passed == total:
            print("🎉 All tests passed!")
            return True
        else:
            print("💥 Some tests failed!")
            return False


def main():
    """Main test execution"""
    test_runner = JJFugitiveAPITest()
    
    try:
        test_runner.start_neovim()
        
        # Give Neovim time to fully initialize
        time.sleep(1)
        
        success = test_runner.run_all_tests()
        return 0 if success else 1
        
    except Exception as e:
        print(f"💥 Fatal error: {e}")
        return 1
    finally:
        test_runner.cleanup()


if __name__ == "__main__":
    sys.exit(main())