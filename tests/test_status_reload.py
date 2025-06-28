#!/usr/bin/env python3
"""
Quick test script for status buffer reload functionality
"""

import os
import sys
import time
import subprocess
import tempfile
import signal

try:
    import pynvim
except ImportError:
    print("Error: pynvim is required. Install with: uv sync")
    sys.exit(1)


def test_status_reload():
    """Test the status buffer reload functionality specifically"""
    socket_path = "/tmp/nvim_reload_test.sock"
    nvim_process = None
    nvim = None
    
    def cleanup():
        if nvim:
            try:
                nvim.command("qall!")
            except:
                pass
            nvim.close()
        if nvim_process:
            nvim_process.terminate()
        if os.path.exists(socket_path):
            os.remove(socket_path)
    
    def timeout_handler(signum, frame):
        print("⏰ Test timed out")
        cleanup()
        sys.exit(1)
    
    # Set timeout
    signal.signal(signal.SIGALRM, timeout_handler)
    signal.alarm(30)  # 30 second timeout
    
    try:
        print("🚀 Testing :JStatus reload functionality")
        
        # Remove old socket
        if os.path.exists(socket_path):
            os.remove(socket_path)
        
        # Start Neovim
        plugin_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        cmd = [
            "nvim", "--headless", "--listen", socket_path,
            "--cmd", f"set rtp+={plugin_dir}",
            "-c", "runtime plugin/jj-fugitive.lua"
        ]
        
        nvim_process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        
        # Wait for socket
        for _ in range(50):
            if os.path.exists(socket_path):
                break
            time.sleep(0.1)
        else:
            print("❌ FAIL: Could not start Neovim")
            return False
        
        # Connect
        nvim = pynvim.attach('socket', path=socket_path)
        print("✅ Connected to Neovim")
        
        # Test 1: Create status buffer
        print("\n--- Test 1: Create status buffer ---")
        nvim.command("JStatus")
        time.sleep(0.5)
        
        # Find buffer
        status_buffer = None
        for buf in nvim.buffers:
            try:
                if "jj-status" in buf.name:
                    status_buffer = buf
                    break
            except:
                pass
        
        if not status_buffer:
            print("❌ FAIL: Could not find status buffer")
            return False
        
        print(f"✅ Found status buffer: {status_buffer.number}")
        initial_lines = len(status_buffer[:])
        print(f"Initial buffer has {initial_lines} lines")
        
        # Test 2: Reload status buffer (simulate pressing 'r')
        print("\n--- Test 2: Reload status buffer ---")
        
        # Switch to the buffer window
        for win in nvim.windows:
            if win.buffer == status_buffer:
                nvim.current.window = win
                break
        
        # Simulate pressing 'r' key
        nvim.feedkeys('r', 'n', True)
        time.sleep(1)
        
        # Check buffer still exists and has content
        try:
            new_lines = len(status_buffer[:])
            print(f"After reload: buffer has {new_lines} lines")
            
            if new_lines > 0:
                content = "\n".join(status_buffer[:10])  # First 10 lines
                if "jj-fugitive Status" in content:
                    print("✅ PASS: Reload successful, buffer has expected content")
                    return True
                else:
                    print("❌ FAIL: Buffer content invalid after reload")
                    print(f"Content: {content}")
                    return False
            else:
                print("❌ FAIL: Buffer empty after reload")
                return False
                
        except Exception as e:
            print(f"❌ FAIL: Error checking buffer after reload: {e}")
            return False
            
    except Exception as e:
        print(f"❌ FAIL: Test error: {e}")
        return False
    finally:
        signal.alarm(0)  # Cancel timeout
        cleanup()


if __name__ == "__main__":
    success = test_status_reload()
    sys.exit(0 if success else 1)