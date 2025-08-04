#!/bin/bash

echo "🔍 Local FUSE Window Layout Debug Script v2"
echo "============================================"

# Kill any existing processes
echo "Cleaning up existing processes..."
pkill -f "Xvfb :97" 2>/dev/null || true
pkill -f "fuse-sdl" 2>/dev/null || true
pkill -f "pulseaudio" 2>/dev/null || true
sleep 2

# Start virtual display with container-like resolution
echo "Starting Xvfb on display :97 with 800x600 resolution..."
Xvfb :97 -screen 0 800x600x24 -ac +extension GLX &
XVFB_PID=$!
export DISPLAY=:97
export SDL_VIDEODRIVER=x11
sleep 3

# Verify display is working
echo "Verifying display..."
if xdpyinfo -display :97 >/dev/null 2>&1; then
    echo "✅ Virtual display :97 is working"
else
    echo "❌ Virtual display failed to start"
    kill $XVFB_PID 2>/dev/null
    exit 1
fi

# Start PulseAudio (like in container)
echo "Starting PulseAudio..."
export PULSE_RUNTIME_PATH=/tmp/pulse_debug
mkdir -p $PULSE_RUNTIME_PATH
pulseaudio --start --exit-idle-time=-1 --daemon=false &
PULSE_PID=$!
sleep 2

# Start FUSE emulator with container-like settings
echo "Starting FUSE emulator (without graphics filter)..."
fuse-sdl --machine 48 --no-sound &
FUSE_PID=$!
sleep 5

# Check if FUSE is still running
if kill -0 $FUSE_PID 2>/dev/null; then
    echo "✅ FUSE emulator is running"
else
    echo "❌ FUSE emulator crashed"
fi

# Check window layout
echo ""
echo "Analyzing window layout..."
echo "Root window tree:"
xwininfo -root -tree -display :97

echo ""
echo "Looking for FUSE windows specifically..."
FUSE_WINDOWS=$(xwininfo -root -tree -display :97 | grep -i fuse)
echo "$FUSE_WINDOWS"

# Extract window dimensions and positions
echo ""
echo "Window analysis:"
if echo "$FUSE_WINDOWS" | grep -q "fuse"; then
    WINDOW_INFO=$(echo "$FUSE_WINDOWS" | head -1)
    echo "FUSE window: $WINDOW_INFO"
    
    # Try to extract dimensions and position
    if echo "$WINDOW_INFO" | grep -q "[0-9]*x[0-9]*+[0-9]*+[0-9]*"; then
        GEOMETRY=$(echo "$WINDOW_INFO" | grep -o "[0-9]*x[0-9]*+[0-9]*+[0-9]*")
        echo "Extracted geometry: $GEOMETRY"
        
        # Parse geometry
        SIZE=$(echo "$GEOMETRY" | cut -d'+' -f1)
        X_OFFSET=$(echo "$GEOMETRY" | cut -d'+' -f2)
        Y_OFFSET=$(echo "$GEOMETRY" | cut -d'+' -f3)
        
        echo "Size: $SIZE, X offset: $X_OFFSET, Y offset: $Y_OFFSET"
    fi
fi

# Test different capture areas
echo ""
echo "🎥 Testing capture areas..."

# Create test directory
mkdir -p /tmp/debug_capture_v2

# Test 1: Full screen capture
echo "Test 1: Full screen capture (800x600+0+0)"
timeout 10 ffmpeg -f x11grab -video_size 800x600 -framerate 1 -i :97.0+0,0 -frames:v 1 -y /tmp/debug_capture_v2/full_screen.png 2>/dev/null &
wait
if [ -f /tmp/debug_capture_v2/full_screen.png ]; then
    echo "✅ Full screen capture successful"
    ls -la /tmp/debug_capture_v2/full_screen.png
else
    echo "❌ Full screen capture failed"
fi

# Test 2: Try to capture the FUSE window directly if we found it
if [ ! -z "$SIZE" ] && [ ! -z "$X_OFFSET" ] && [ ! -z "$Y_OFFSET" ]; then
    echo "Test 2: Capture FUSE window directly ($SIZE+$X_OFFSET+$Y_OFFSET)"
    timeout 10 ffmpeg -f x11grab -video_size $SIZE -framerate 1 -i :97.0+$X_OFFSET,$Y_OFFSET -frames:v 1 -y /tmp/debug_capture_v2/fuse_window.png 2>/dev/null &
    wait
    if [ -f /tmp/debug_capture_v2/fuse_window.png ]; then
        echo "✅ FUSE window capture successful"
        ls -la /tmp/debug_capture_v2/fuse_window.png
    else
        echo "❌ FUSE window capture failed"
    fi
fi

# Test 3: Container-like capture (640x480+80+60)
echo "Test 3: Container-like capture (640x480+80+60)"
timeout 10 ffmpeg -f x11grab -video_size 640x480 -framerate 1 -i :97.0+80,60 -frames:v 1 -y /tmp/debug_capture_v2/container_like.png 2>/dev/null &
wait
if [ -f /tmp/debug_capture_v2/container_like.png ]; then
    echo "✅ Container-like capture successful"
    ls -la /tmp/debug_capture_v2/container_like.png
else
    echo "❌ Container-like capture failed"
fi

# Test 4: Center capture (try to capture from center of screen)
echo "Test 4: Center capture (320x240+240+180)"
timeout 10 ffmpeg -f x11grab -video_size 320x240 -framerate 1 -i :97.0+240,180 -frames:v 1 -y /tmp/debug_capture_v2/center_capture.png 2>/dev/null &
wait
if [ -f /tmp/debug_capture_v2/center_capture.png ]; then
    echo "✅ Center capture successful"
    ls -la /tmp/debug_capture_v2/center_capture.png
else
    echo "❌ Center capture failed"
fi

echo ""
echo "📊 Capture Results Summary:"
echo "=========================="
ls -la /tmp/debug_capture_v2/

echo ""
echo "🔍 Image Analysis:"
echo "=================="
for img in /tmp/debug_capture_v2/*.png; do
    if [ -f "$img" ]; then
        echo "$(basename $img): $(file $img | cut -d: -f2-)"
    fi
done

echo ""
echo "🧹 Cleaning up..."
kill $FUSE_PID 2>/dev/null || true
kill $PULSE_PID 2>/dev/null || true
kill $XVFB_PID 2>/dev/null || true
sleep 2

echo ""
echo "✅ Debug complete! Check /tmp/debug_capture_v2/ for captured images"
echo ""
echo "💡 Next steps:"
echo "1. Examine the captured images to see which contains actual content"
echo "2. Compare with the container window layout from logs"
echo "3. Identify the correct capture parameters"
