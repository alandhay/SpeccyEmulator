#!/bin/bash

echo "🧪 Simple FUSE Test"
echo "==================="

# Clean up
pkill -f fuse 2>/dev/null || true
pkill -f Xvfb 2>/dev/null || true
sleep 2

# Start virtual display
echo "Starting virtual display..."
export DISPLAY=:96
Xvfb :96 -screen 0 800x600x24 -ac &
XVFB_PID=$!
sleep 3

echo "Testing FUSE startup..."
echo "Command: fuse-sdl --machine 48 --no-sound"

# Test FUSE with timeout
timeout 10s fuse-sdl --machine 48 --no-sound &
FUSE_PID=$!

sleep 5

if pgrep -f fuse-sdl > /dev/null; then
    echo "✅ FUSE is running!"
    ps aux | grep fuse-sdl | grep -v grep
else
    echo "❌ FUSE not running"
fi

# Cleanup
echo "Cleaning up..."
kill $FUSE_PID 2>/dev/null || true
kill $XVFB_PID 2>/dev/null || true
pkill -f fuse 2>/dev/null || true
pkill -f Xvfb 2>/dev/null || true

echo "Test completed"
