#!/bin/bash
# Direct Key Injection Test - Bypass window activation issues
# Test sending keys directly without trying to activate/focus the window

set -e

echo "🧪 EXPERIMENT 3: Direct Key Injection (No Window Activation)"
echo "============================================================"

# Configuration matching production
DISPLAY_NUM=99
DISPLAY_SIZE="320x240x24"
export DISPLAY=:${DISPLAY_NUM}

echo "📺 Starting Xvfb on display :${DISPLAY_NUM}"

# Kill any existing processes
pkill -f "Xvfb :${DISPLAY_NUM}" 2>/dev/null || true
pkill -f "fuse-sdl" 2>/dev/null || true
sleep 2

# Start Xvfb
Xvfb :${DISPLAY_NUM} -screen 0 ${DISPLAY_SIZE} -ac &
XVFB_PID=$!
echo "✅ Xvfb started with PID: ${XVFB_PID}"

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

echo "🔍 Checking window properties..."
xwininfo -display :${DISPLAY_NUM} -id ${FUSE_WINDOW} | grep -E "(Map State|Class|Override Redirect)"

echo ""
echo "⌨️  METHOD 1: Direct key to window (no activation)..."
echo "   Sending ENTER key directly to window..."
xdotool key --window ${FUSE_WINDOW} Return 2>&1 || echo "   ⚠️  Direct window key failed"
sleep 2

echo ""
echo "⌨️  METHOD 2: Global key injection..."
echo "   Sending ENTER key globally to display..."
DISPLAY=:${DISPLAY_NUM} xdotool key Return 2>&1 || echo "   ⚠️  Global key failed"
sleep 2

echo ""
echo "⌨️  METHOD 3: Using xev to monitor events..."
echo "   Starting xev to monitor key events..."
timeout 10s xev -display :${DISPLAY_NUM} -root &
XEV_PID=$!
sleep 2

echo "   Sending test key while monitoring..."
DISPLAY=:${DISPLAY_NUM} xdotool key space 2>&1 || echo "   ⚠️  Monitored key failed"
sleep 3

kill ${XEV_PID} 2>/dev/null || true

echo ""
echo "⌨️  METHOD 4: Alternative key injection with xte..."
if command -v xte >/dev/null 2>&1; then
    echo "   Using xte for key injection..."
    echo "key Return" | DISPLAY=:${DISPLAY_NUM} xte 2>&1 || echo "   ⚠️  xte failed"
else
    echo "   xte not available, skipping..."
fi

echo ""
echo "⌨️  METHOD 5: Raw X11 key events..."
echo "   Trying to send raw key events..."
# This is a more direct approach
DISPLAY=:${DISPLAY_NUM} xdotool keydown Return keyup Return 2>&1 || echo "   ⚠️  Raw key events failed"
sleep 2

echo ""
echo "🔍 Final process check..."
if ps -p ${FUSE_PID} > /dev/null 2>&1; then
    echo "✅ FUSE process still running (PID: ${FUSE_PID})"
    
    # Check if FUSE is consuming CPU (sign it's processing input)
    CPU_USAGE=$(ps -p ${FUSE_PID} -o %cpu --no-headers 2>/dev/null || echo "0.0")
    echo "   CPU usage: ${CPU_USAGE}%"
    
    # Check memory usage
    MEM_USAGE=$(ps -p ${FUSE_PID} -o %mem --no-headers 2>/dev/null || echo "0.0")
    echo "   Memory usage: ${MEM_USAGE}%"
else
    echo "❌ FUSE process has exited"
fi

echo ""
echo "⏱️  Keeping processes running for 10 seconds..."
sleep 10

echo ""
echo "🧹 Cleaning up..."
kill ${FUSE_PID} 2>/dev/null || true
kill ${XVFB_PID} 2>/dev/null || true
sleep 2

echo "✅ Direct key injection test complete!"
echo ""
echo "📋 ANALYSIS:"
echo "- Window activation failed due to missing window manager"
echo "- This is likely the same issue in production"
echo "- Need to test direct key injection methods"
echo "- May need to implement different input strategy"
