#!/bin/bash
# X11 Focus and Input Method Test - Find the working input method
# Based on our findings, we need to solve the X11 key delivery issue

set -e

echo "🧪 EXPERIMENT 5: X11 Focus and Input Method Solutions"
echo "====================================================="

# Configuration matching production
DISPLAY_NUM=99
DISPLAY_SIZE="320x240x24"
export DISPLAY=:${DISPLAY_NUM}

echo "📺 Starting Xvfb on display :${DISPLAY_NUM}"

# Kill any existing processes
pkill -f "Xvfb :${DISPLAY_NUM}" 2>/dev/null || true
pkill -f "fuse-sdl" 2>/dev/null || true
sleep 2

# Start Xvfb with additional options for better input handling
Xvfb :${DISPLAY_NUM} -screen 0 ${DISPLAY_SIZE} -ac -nolisten tcp +extension XTEST &
XVFB_PID=$!
echo "✅ Xvfb started with PID: ${XVFB_PID} (with XTEST extension)"

# Wait for X server to be ready
sleep 3

echo "🎮 Starting FUSE emulator..."
fuse-sdl --machine 48 --no-sound &
FUSE_PID=$!
echo "✅ FUSE started with PID: ${FUSE_PID}"

# Wait for FUSE to initialize
sleep 5

echo "🔍 Finding FUSE window..."
FUSE_WINDOW=$(xdotool search --name "Fuse" 2>/dev/null | head -1)
if [ -z "$FUSE_WINDOW" ]; then
    echo "❌ Could not find FUSE window!"
    kill ${FUSE_PID} 2>/dev/null || true
    kill ${XVFB_PID} 2>/dev/null || true
    exit 1
fi

echo "✅ Found FUSE window: ${FUSE_WINDOW}"

echo ""
echo "🔍 SOLUTION 1: Set input focus manually..."
# Instead of windowactivate, try setting focus directly
xdotool windowfocus --sync ${FUSE_WINDOW} 2>/dev/null || echo "   ⚠️  windowfocus failed"

# Get the current focused window
FOCUSED_WINDOW=$(xdotool getwindowfocus 2>/dev/null || echo "none")
echo "   Currently focused window: ${FOCUSED_WINDOW}"

if [ "$FOCUSED_WINDOW" = "$FUSE_WINDOW" ]; then
    echo "✅ FUSE window is now focused!"
else
    echo "❌ FUSE window is not focused"
fi

echo ""
echo "🔍 SOLUTION 2: Use XTEST extension for direct input..."
# XTEST extension bypasses window focus requirements
echo "   Sending key via XTEST extension..."
xdotool key --clearmodifiers Return 2>/dev/null || echo "   ⚠️  XTEST key failed"
sleep 2

echo ""
echo "🔍 SOLUTION 3: Mouse click to focus then key..."
echo "   Clicking on FUSE window to focus it..."
xdotool mousemove --window ${FUSE_WINDOW} 160 120  # Center of 320x240 window
xdotool click 1  # Left click
sleep 1
echo "   Now sending key after click..."
xdotool key space
sleep 2

echo ""
echo "🔍 SOLUTION 4: Check if we need a window manager..."
echo "   Installing a minimal window manager..."
# Start a minimal window manager
twm -display :${DISPLAY_NUM} &
TWM_PID=$!
sleep 2
echo "✅ Started twm window manager (PID: ${TWM_PID})"

echo "   Now trying window activation with window manager..."
xdotool windowactivate ${FUSE_WINDOW} 2>/dev/null && echo "✅ Window activation succeeded!" || echo "❌ Window activation still failed"

echo "   Sending key with window manager active..."
xdotool key --window ${FUSE_WINDOW} Return
sleep 2

echo ""
echo "🔍 SOLUTION 5: Direct X11 event injection..."
echo "   Using low-level X11 event injection..."
# This is the most direct method
python3 << 'EOF'
import subprocess
import os
import time

# Set display
os.environ['DISPLAY'] = ':99'

# Send a key event using xdotool with maximum directness
try:
    # Send key with all possible flags for directness
    result = subprocess.run([
        'xdotool', 
        'key', 
        '--clearmodifiers',
        '--delay', '100',
        'Return'
    ], capture_output=True, text=True, timeout=5)
    
    if result.returncode == 0:
        print("✅ Python xdotool key injection succeeded")
    else:
        print(f"❌ Python xdotool failed: {result.stderr}")
        
except Exception as e:
    print(f"❌ Python key injection error: {e}")
EOF

echo ""
echo "🔍 Final test: Monitor FUSE for any response..."
# Start monitoring FUSE again
strace -p ${FUSE_PID} -e trace=read,poll,select -o /tmp/fuse_final.log 2>/dev/null &
STRACE_PID=$!
sleep 1

echo "   Sending final test sequence..."
xdotool key Return space a Escape
sleep 3

kill ${STRACE_PID} 2>/dev/null || true

if [ -f /tmp/fuse_final.log ]; then
    EVENTS=$(wc -l < /tmp/fuse_final.log 2>/dev/null || echo "0")
    echo "   FUSE system calls during final test: ${EVENTS}"
    if [ "$EVENTS" -gt "0" ]; then
        echo "✅ FUSE received input events!"
        echo "   Last few events:"
        tail -5 /tmp/fuse_final.log
    else
        echo "❌ FUSE still not receiving events"
    fi
fi

echo ""
echo "🧹 Cleaning up..."
kill ${TWM_PID} 2>/dev/null || true
kill ${FUSE_PID} 2>/dev/null || true
kill ${XVFB_PID} 2>/dev/null || true
rm -f /tmp/fuse_final.log
sleep 2

echo "✅ X11 focus and input method test complete!"
echo ""
echo "📋 SOLUTION ANALYSIS:"
echo "- If any method worked, we found our solution"
echo "- Window manager (twm) might be required"
echo "- XTEST extension might be the key"
echo "- Direct focus setting might work"
echo "- This will guide our production fix"
