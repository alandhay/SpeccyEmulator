#!/bin/bash
# Key Injection Test - Test if we can send keys to FUSE
# This tests the core functionality that's failing in production

set -e

echo "🧪 EXPERIMENT 2: Key Injection Test"
echo "==================================="

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

echo "🎮 Starting FUSE emulator (without graphics filter)..."
# Remove the problematic --graphics-filter none option
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

echo "🎯 Testing window activation..."
xdotool windowactivate ${FUSE_WINDOW}
sleep 1

echo "🎯 Testing window focus..."
xdotool windowfocus ${FUSE_WINDOW}
sleep 1

echo "⌨️  Testing key injection..."
echo "   Sending ENTER key (should get past splash screen)..."
xdotool key --window ${FUSE_WINDOW} Return
sleep 2

echo "   Sending 'LOAD \"\"' command..."
xdotool type --window ${FUSE_WINDOW} 'LOAD ""'
sleep 1

echo "   Sending ENTER to execute..."
xdotool key --window ${FUSE_WINDOW} Return
sleep 2

echo "   Sending some test characters..."
xdotool type --window ${FUSE_WINDOW} 'PRINT "HELLO WORLD"'
sleep 1
xdotool key --window ${FUSE_WINDOW} Return
sleep 2

echo "🔍 Checking if FUSE process is still running..."
if ps -p ${FUSE_PID} > /dev/null 2>&1; then
    echo "✅ FUSE process still running"
else
    echo "❌ FUSE process has exited"
fi

echo "🔍 Checking window status..."
if xdotool search --name "Fuse" > /dev/null 2>&1; then
    echo "✅ FUSE window still exists"
    
    echo "🔍 Getting current window info..."
    xwininfo -display :${DISPLAY_NUM} -id ${FUSE_WINDOW}
else
    echo "❌ FUSE window no longer exists"
fi

echo ""
echo "⏱️  Keeping processes running for 15 seconds for observation..."
echo "   In production, this is where we'd see the emulator respond to input"
sleep 15

echo ""
echo "🧹 Cleaning up..."
kill ${FUSE_PID} 2>/dev/null || true
kill ${XVFB_PID} 2>/dev/null || true
sleep 2

echo "✅ Key injection test complete!"
echo ""
echo "📋 NEXT STEPS:"
echo "- If keys were sent successfully, the issue is in the WebSocket pipeline"
echo "- If keys failed to send, the issue is in X11/xdotool configuration"
echo "- Check the production server logs to see if similar errors occur"
