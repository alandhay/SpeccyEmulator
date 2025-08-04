#!/bin/bash
# Basic FUSE Emulator Test - Check if FUSE starts and is accessible
# This tests the fundamental setup before we worry about key injection

set -e

echo "🧪 EXPERIMENT 1: Basic FUSE Startup Test"
echo "========================================"

# Configuration matching production
DISPLAY_NUM=99
DISPLAY_SIZE="320x240x24"
export DISPLAY=:${DISPLAY_NUM}

echo "📺 Starting Xvfb on display :${DISPLAY_NUM} with size ${DISPLAY_SIZE}"

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
fuse-sdl --machine 48 --no-sound --graphics-filter none &
FUSE_PID=$!
echo "✅ FUSE started with PID: ${FUSE_PID}"

# Wait for FUSE to initialize
sleep 5

echo "🔍 Checking X11 window information..."
echo "--- Root window tree ---"
xwininfo -display :${DISPLAY_NUM} -tree -root

echo ""
echo "🔍 Looking for FUSE windows..."
FUSE_WINDOWS=$(xdotool search --name "Fuse" 2>/dev/null || echo "")
if [ -n "$FUSE_WINDOWS" ]; then
    echo "✅ Found FUSE windows: $FUSE_WINDOWS"
    for window in $FUSE_WINDOWS; do
        echo "  Window ID: $window"
        xwininfo -display :${DISPLAY_NUM} -id $window
        echo ""
    done
else
    echo "❌ No FUSE windows found by name 'Fuse'"
    echo "🔍 Searching for any SDL windows..."
    SDL_WINDOWS=$(xdotool search --class "SDL_App" 2>/dev/null || echo "")
    if [ -n "$SDL_WINDOWS" ]; then
        echo "✅ Found SDL windows: $SDL_WINDOWS"
    else
        echo "❌ No SDL windows found either"
    fi
fi

echo ""
echo "📊 Process Status:"
echo "Xvfb PID: ${XVFB_PID} - $(ps -p ${XVFB_PID} -o comm= 2>/dev/null || echo 'NOT RUNNING')"
echo "FUSE PID: ${FUSE_PID} - $(ps -p ${FUSE_PID} -o comm= 2>/dev/null || echo 'NOT RUNNING')"

echo ""
echo "⏱️  Keeping processes running for 30 seconds for manual inspection..."
echo "   You can run 'ps aux | grep -E \"Xvfb|fuse\"' in another terminal"
sleep 30

echo ""
echo "🧹 Cleaning up..."
kill ${FUSE_PID} 2>/dev/null || true
kill ${XVFB_PID} 2>/dev/null || true
sleep 2

echo "✅ Test complete!"
echo ""
echo "📋 RESULTS SUMMARY:"
echo "- Xvfb startup: $([ $XVFB_PID ] && echo "✅ SUCCESS" || echo "❌ FAILED")"
echo "- FUSE startup: $([ $FUSE_PID ] && echo "✅ SUCCESS" || echo "❌ FAILED")"
echo "- Window detection: $([ -n "$FUSE_WINDOWS" ] && echo "✅ SUCCESS" || echo "❌ FAILED")"
