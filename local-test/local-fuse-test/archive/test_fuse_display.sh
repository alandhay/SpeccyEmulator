#!/bin/bash

# Test FUSE Display Without Streaming
# Quick test to verify FUSE runs and displays correctly
echo "🖥️ FUSE Display Test (No Streaming)"
echo "==================================="

DISPLAY_NUM=":97"

echo "Virtual Display: $DISPLAY_NUM"
echo "Duration: 30 seconds"
echo ""

# Clean up any existing processes
echo "🧹 Cleaning up existing processes..."
pkill -f fuse 2>/dev/null || true
pkill -f Xvfb 2>/dev/null || true
sleep 2

echo ""
echo "🖥️ Starting virtual X11 display..."
export DISPLAY=$DISPLAY_NUM
Xvfb $DISPLAY_NUM -screen 0 800x600x24 -ac +extension GLX &
XVFB_PID=$!
sleep 3

if ! pgrep -f "Xvfb $DISPLAY_NUM" > /dev/null; then
    echo "❌ Failed to start virtual display!"
    exit 1
fi

echo "✅ Virtual display started (PID: $XVFB_PID)"

echo ""
echo "🎮 Starting FUSE emulator for 30 seconds..."
echo "==========================================="
echo "This will test if FUSE can start and run properly"
echo ""

# Start FUSE and let it run for 30 seconds
timeout 30s fuse-sdl --machine 48 --no-sound &
FUSE_PID=$!

# Wait and monitor
sleep 5
if pgrep -f fuse-sdl > /dev/null; then
    echo "✅ FUSE started successfully (PID: $FUSE_PID)"
    echo "⏱️ Running for 30 seconds..."
    
    # Show process info
    echo ""
    echo "📊 Process Status:"
    ps aux | grep -E "(fuse|Xvfb)" | grep -v grep
    
    # Wait for timeout
    wait $FUSE_PID 2>/dev/null
    
    echo ""
    echo "✅ FUSE test completed successfully!"
else
    echo "❌ FUSE failed to start!"
fi

# Cleanup
echo ""
echo "🧹 Cleaning up..."
kill $XVFB_PID 2>/dev/null || true
pkill -f fuse 2>/dev/null || true

echo "✅ Test completed"
echo ""
echo "🎯 If FUSE started successfully:"
echo "   → Ready to run streaming scripts"
echo "   → Try: ./stream_fuse_to_youtube.sh"
echo ""
echo "🎯 If FUSE failed to start:"
echo "   → Run: ./test_fuse_setup.sh"
echo "   → Check FUSE installation"
echo "   → Verify X11 dependencies"
