#!/bin/bash

# Debug RTMP Handshake Issues
echo "🔍 RTMP Handshake Debug"
echo "======================"

STREAM_KEY="v8s4-qp8m-xvw3-39z7-3dhm"
RTMP_URL="rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY"

echo "Stream Key: $STREAM_KEY"
echo "RTMP URL: $RTMP_URL"
echo ""

# Kill any existing FFmpeg processes
echo "1. Stopping existing streams..."
pkill -f "ffmpeg.*youtube" 2>/dev/null || true
sleep 2

# Start Xvfb if not running
echo "2. Ensuring virtual display is running..."
if ! pgrep -f "Xvfb :99" > /dev/null; then
    Xvfb :99 -screen 0 320x240x24 -ac &
    XVFB_PID=$!
    sleep 3
    echo "Started Xvfb with PID: $XVFB_PID"
else
    echo "Xvfb already running"
fi

# Create test pattern
DISPLAY=:99 xsetroot -solid green &

echo ""
echo "3. Testing RTMP with maximum debug output..."
echo "==========================================="

# Test with very verbose RTMP debugging
ffmpeg -f x11grab \
       -i ":99.0+0,0" \
       -s 320x240 \
       -r 25 \
       -c:v libx264 \
       -preset ultrafast \
       -tune zerolatency \
       -b:v 2500k \
       -maxrate 2500k \
       -bufsize 5000k \
       -pix_fmt yuv420p \
       -g 50 \
       -keyint_min 25 \
       -f flv \
       "$RTMP_URL" \
       -t 20 \
       -v trace \
       -report \
       -y 2>&1 | tee rtmp_debug.log

echo ""
echo "4. Analyzing RTMP debug output..."
echo "================================"

if [ -f rtmp_debug.log ]; then
    echo "Checking for RTMP handshake issues:"
    
    if grep -q "RTMP_Connect" rtmp_debug.log; then
        echo "✅ RTMP connection initiated"
    else
        echo "❌ No RTMP connection attempt found"
    fi
    
    if grep -q "Handshake" rtmp_debug.log; then
        echo "✅ RTMP handshake attempted"
    else
        echo "❌ No RTMP handshake found"
    fi
    
    if grep -q "connect" rtmp_debug.log; then
        echo "✅ RTMP connect command sent"
    else
        echo "❌ No RTMP connect command"
    fi
    
    if grep -q "publish" rtmp_debug.log; then
        echo "✅ RTMP publish command sent"
    else
        echo "❌ No RTMP publish command"
    fi
    
    if grep -q "rejected\|failed\|error" rtmp_debug.log; then
        echo "❌ RTMP errors found:"
        grep -i "rejected\|failed\|error" rtmp_debug.log | head -5
    fi
    
    echo ""
    echo "Last 10 lines of RTMP debug:"
    tail -10 rtmp_debug.log
fi

echo ""
echo "5. Alternative test with different RTMP parameters..."
echo "===================================================="

# Try with different RTMP settings that might work better
echo "Testing with alternative RTMP configuration..."

ffmpeg -f x11grab \
       -i ":99.0+0,0" \
       -s 320x240 \
       -r 25 \
       -c:v libx264 \
       -preset ultrafast \
       -b:v 1500k \
       -pix_fmt yuv420p \
       -f flv \
       -rtmp_live live \
       -rtmp_conn "S:$STREAM_KEY" \
       "$RTMP_URL" \
       -t 15 \
       -y 2>&1 | head -20

echo ""
echo "Debug complete. Check rtmp_debug.log for detailed RTMP protocol analysis."
