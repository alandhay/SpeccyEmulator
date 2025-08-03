#!/usr/bin/env python3
"""
Debug script to test FUSE emulator interaction
"""
import subprocess
import time
import os

def run_command(cmd, description):
    """Run a command and show the result"""
    print(f"\n=== {description} ===")
    print(f"Command: {' '.join(cmd)}")
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        print(f"Return code: {result.returncode}")
        if result.stdout:
            print(f"STDOUT:\n{result.stdout}")
        if result.stderr:
            print(f"STDERR:\n{result.stderr}")
        return result.returncode == 0
    except subprocess.TimeoutExpired:
        print("Command timed out")
        return False
    except Exception as e:
        print(f"Error: {e}")
        return False

def main():
    print("FUSE Emulator Diagnostic Script")
    print("=" * 50)
    
    # Set environment
    os.environ['DISPLAY'] = ':99'
    
    # Check if DISPLAY is working
    run_command(['xdpyinfo'], "Check X11 Display")
    
    # List all windows
    run_command(['xwininfo', '-tree', '-root'], "List all X11 windows")
    
    # Search for FUSE window specifically
    run_command(['xdotool', 'search', '--name', 'Fuse'], "Search for FUSE window")
    
    # Try alternative window searches
    run_command(['xdotool', 'search', '--class', 'fuse-sdl'], "Search by class name")
    run_command(['xdotool', 'search', '--classname', 'fuse-sdl'], "Search by class name (alt)")
    
    # Check if FUSE process is running
    run_command(['ps', 'aux'], "List all processes")
    
    # Try to get window info for any FUSE window
    try:
        result = subprocess.run(['xdotool', 'search', '--name', 'Fuse'], 
                              capture_output=True, text=True)
        if result.returncode == 0 and result.stdout.strip():
            window_id = result.stdout.strip().split('\n')[0]
            print(f"\nFound FUSE window ID: {window_id}")
            
            # Get window info
            run_command(['xwininfo', '-id', window_id], f"Window info for {window_id}")
            
            # Try to focus and send a key
            print(f"\n=== Testing key input to window {window_id} ===")
            run_command(['xdotool', 'windowfocus', window_id], "Focus window")
            time.sleep(1)
            run_command(['xdotool', 'key', '--window', window_id, 'Return'], "Send ENTER key")
            time.sleep(1)
            run_command(['xdotool', 'key', '--window', window_id, 'space'], "Send SPACE key")
            
    except Exception as e:
        print(f"Error testing window interaction: {e}")
    
    print("\n" + "=" * 50)
    print("Diagnostic complete")

if __name__ == "__main__":
    main()
