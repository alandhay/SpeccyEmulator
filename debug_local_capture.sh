#!/bin/bash

echo "🔍 Local FUSE Window Layout Debug Script"
echo "========================================"

# Kill any existing processes
echo "Cleaning up existing processes..."
pkill -f "Xvfb :98" 2>/dev/null || true
pkill -f "fuse-sdl" 2>/dev/null || true
sleep 2

# Start virtual display
echo "Starting Xvfb on display :98..."
Xvfb :98 -screen 0 800x600x24 -ac +extension GLX &
XVFB_PID=$!
export DISPLAY=:98
sleep 3

# Verify display is working
echo "Verifying display..."
if xdpyinfo -display :98 >/dev/null 2>&1; then
    echo "✅ Virtual display :98 is working"
else
    echo "❌ Virtual display failed to start"
    kill $XVFB_PID 2>/dev/null
    exit 1
fi

# Start FUSE emulator
echo "Starting FUSE emulator..."
fuse-sdl --machine 48 --no-sound --graphics-filter none &
FUSE_PID=$!
sleep 5

# Check window layout
echo "Analyzing window layout..."
echo "Root window tree:"
xwininfo -root -tree -display :98

echo ""
echo "Looking for FUSE windows specifically..."
xwininfo -root -tree -display :98 | grep -i fuse

echo ""
echo "All windows with dimensions:"
xwininfo -root -tree -display :98 | grep -E "0x[0-9a-f]+" | head -10

# Test different capture areas
echo ""
echo "🎥 Testing capture areas..."

# Create test directory
mkdir -p /tmp/debug_capture

# Test 1: Full screen capture
echo "Test 1: Full screen capture (800x600+0+0)"
timeout 5 ffmpeg -f x11grab -video_size 800x600 -framerate 1 -i :98.0+0,0 -frames:v 1 -y /tmp/debug_capture/full_screen.png 2>/dev/null
if [ -f /tmp/debug_capture/full_screen.png ]; then
    echo "✅ Full screen capture successful"
    ls -la /tmp/debug_capture/full_screen.png
else
    echo "❌ Full screen capture failed"
fi

# Test 2: 640x480 from top-left
echo "Test 2: 640x480 from top-left (+0+0)"
timeout 5 ffmpeg -f x11grab -video_size 640x480 -framerate 1 -i :98.0+0,0 -frames:v 1 -y /tmp/debug_capture/topleft_640x480.png 2>/dev/null
if [ -f /tmp/debug_capture/topleft_640x480.png ]; then
    echo "✅ Top-left 640x480 capture successful"
    ls -la /tmp/debug_capture/topleft_640x480.png
else
    echo "❌ Top-left 640x480 capture failed"
fi

# Test 3: 640x480 with offset
echo "Test 3: 640x480 with offset (+80+60)"
timeout 5 ffmpeg -f x11grab -video_size 640x480 -framerate 1 -i :98.0+80,60 -frames:v 1 -y /tmp/debug_capture/offset_640x480.png 2>/dev/null
if [ -f /tmp/debug_capture/offset_640x480.png ]; then
    echo "✅ Offset 640x480 capture successful"
    ls -la /tmp/debug_capture/offset_640x480.png
else
    echo "❌ Offset 640x480 capture failed"
fi

# Test 4: Native ZX Spectrum resolution
echo "Test 4: Native ZX Spectrum resolution (256x192+80+60)"
timeout 5 ffmpeg -f x11grab -video_size 256x192 -framerate 1 -i :98.0+80,60 -frames:v 1 -y /tmp/debug_capture/native_256x192.png 2>/dev/null
if [ -f /tmp/debug_capture/native_256x192.png ]; then
    echo "✅ Native 256x192 capture successful"
    ls -la /tmp/debug_capture/native_256x192.png
else
    echo "❌ Native 256x192 capture failed"
fi

echo ""
echo "📊 Capture Results Summary:"
echo "=========================="
ls -la /tmp/debug_capture/

echo ""
echo "🧹 Cleaning up..."
kill $FUSE_PID 2>/dev/null || true
kill $XVFB_PID 2>/dev/null || true
sleep 2

echo ""
echo "✅ Debug complete! Check /tmp/debug_capture/ for captured images"
echo "You can examine the images to see which capture area contains the actual emulator content"
