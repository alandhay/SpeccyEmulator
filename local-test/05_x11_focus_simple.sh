#!/bin/bash
# Simplified X11 Focus Test - Test key delivery methods without twm
# Focus on the most promising solutions

set -e

echo "🧪 EXPERIMENT 5: X11 Key Delivery Solutions (Simplified)"
echo "========================================================"

# Configuration matching production
DISPLAY_NUM=99
DISPLAY_SIZE="320x240x24"
export DISPLAY=:${DISPLAY_NUM}

echo "📺 Starting Xvfb with XTEST extension..."

# Kill any existing processes
pkill -f "Xvfb :${DISPLAY_NUM}" 2>/dev/null || true
pkill -f "fuse-sdl" 2>/dev/null || true
sleep 2

# Start Xvfb with XTEST extension (critical for input)
Xvfb :${DISPLAY_NUM} -screen 0 ${DISPLAY_SIZE} -ac -nolisten tcp +extension XTEST &
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

# Start monitoring FUSE input
echo "🔍 Starting input monitoring..."
strace -p ${FUSE_PID} -e trace=read,poll,select -o /tmp/fuse_test.log 2>/dev/null &
STRACE_PID=$!
sleep 1

echo ""
echo "⌨️  METHOD 1: Direct key with clearmodifiers..."
xdotool key --clearmodifiers --delay 100 Return 2>/dev/null || echo "   Failed"
sleep 2

echo ""
echo "⌨️  METHOD 2: Mouse click to focus + key..."
echo "   Clicking center of FUSE window..."
xdotool mousemove --window ${FUSE_WINDOW} 160 120
xdotool click --window ${FUSE_WINDOW} 1
sleep 1
echo "   Sending key after click..."
xdotool key space
sleep 2

echo ""
echo "⌨️  METHOD 3: Set window focus explicitly..."
# Try to focus the window
DISPLAY=:${DISPLAY_NUM} xdotool windowfocus ${FUSE_WINDOW} 2>/dev/null || echo "   Focus failed"
sleep 1
xdotool key a
sleep 2

echo ""
echo "⌨️  METHOD 4: Global key injection (no window targeting)..."
DISPLAY=:${DISPLAY_NUM} xdotool key Escape
sleep 2

echo ""
echo "⌨️  METHOD 5: Raw keydown/keyup events..."
xdotool keydown --clearmodifiers Return
sleep 0.1
xdotool keyup Return
sleep 2

echo ""
echo "⌨️  METHOD 6: Type command (for text input)..."
xdotool type --clearmodifiers --delay 100 "HELLO"
sleep 2

echo ""
echo "🔍 Stopping monitoring and checking results..."
kill ${STRACE_PID} 2>/dev/null || true
sleep 1

if [ -f /tmp/fuse_test.log ]; then
    EVENTS=$(wc -l < /tmp/fuse_test.log 2>/dev/null || echo "0")
    echo "📊 FUSE system calls during all tests: ${EVENTS}"
    
    if [ "$EVENTS" -gt "0" ]; then
        echo "✅ SUCCESS! FUSE received input events!"
        echo "📋 Event details:"
        cat /tmp/fuse_test.log | head -10
        
        # Check which method worked by timing
        echo ""
        echo "🕐 Event timing analysis:"
        cat /tmp/fuse_test.log | grep -E "(read|poll|select)" | tail -5
    else
        echo "❌ FUSE still not receiving any input events"
        echo "🔍 This suggests a fundamental X11 input delivery issue"
    fi
else
    echo "❌ No monitoring log found"
fi

echo ""
echo "🔍 Additional diagnostics..."

# Check if FUSE window has input focus
FOCUSED=$(xdotool getwindowfocus 2>/dev/null || echo "none")
echo "Currently focused window: ${FOCUSED}"
echo "FUSE window ID: ${FUSE_WINDOW}"

if [ "$FOCUSED" = "$FUSE_WINDOW" ]; then
    echo "✅ FUSE window has focus"
else
    echo "❌ FUSE window does not have focus"
fi

# Check window properties
echo ""
echo "🔍 FUSE window properties:"
xwininfo -id ${FUSE_WINDOW} | grep -E "(Map State|Class|Input|Focus)"

echo ""
echo "🔍 X11 input method info:"
echo "DISPLAY: $DISPLAY"
echo "XTEST extension available: $(xdpyinfo -display :${DISPLAY_NUM} | grep -i xtest || echo 'Not found')"

echo ""
echo "⏱️  Final observation (5 seconds)..."
sleep 5

echo ""
echo "🧹 Cleaning up..."
kill ${FUSE_PID} 2>/dev/null || true
kill ${XVFB_PID} 2>/dev/null || true
rm -f /tmp/fuse_test.log
sleep 2

echo "✅ Simplified X11 focus test complete!"
echo ""
echo "📋 CRITICAL FINDINGS:"
echo "- If EVENTS > 0: We found a working input method!"
echo "- If EVENTS = 0: Need to investigate X11 input architecture"
echo "- Focus status and window properties provide clues"
echo "- XTEST extension availability is crucial"
