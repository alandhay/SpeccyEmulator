#!/bin/bash

# Debug FFmpeg Streaming Issues
echo "🔍 FFmpeg Streaming Debug"
echo "========================"

echo "1. Testing basic network connectivity..."
echo "========================================"
ping -c 3 8.8.8.8
echo ""

echo "2. Testing YouTube RTMP endpoint..."
echo "=================================="
timeout 5 telnet a.rtmp.youtube.com 1935 2>&1 | head -3
echo ""

echo "3. Testing with minimal FFmpeg command..."
echo "========================================"
echo "Running 10-second test with maximum verbosity..."

ffmpeg -f lavfi -i "testsrc2=size=320x240:rate=25" \
       -c:v libx264 -preset ultrafast \
       -b:v 1000k -pix_fmt yuv420p \
       -f flv "rtmp://a.rtmp.youtube.com/live2/v8s4-qp8m-xvw3-39z7-3dhm" \
       -t 10 \
       -v debug \
       -y 2>&1 | tee ffmpeg_debug.log

echo ""
echo "4. Analyzing debug output..."
echo "==========================="

if [ -f ffmpeg_debug.log ]; then
    echo "Last 20 lines of debug output:"
    tail -20 ffmpeg_debug.log
    echo ""
    
    # Check for specific error patterns
    if grep -q "Connection refused" ffmpeg_debug.log; then
        echo "❌ ISSUE: Connection refused - RTMP server not accepting"
    elif grep -q "Connection timed out" ffmpeg_debug.log; then
        echo "❌ ISSUE: Connection timeout - Network/firewall problem"
    elif grep -q "403" ffmpeg_debug.log; then
        echo "❌ ISSUE: 403 Forbidden - Authentication/stream key problem"
    elif grep -q "404" ffmpeg_debug.log; then
        echo "❌ ISSUE: 404 Not Found - Wrong endpoint"
    elif grep -q "Stream not found" ffmpeg_debug.log; then
        echo "❌ ISSUE: Stream not found - Invalid stream key"
    elif grep -q "frame=" ffmpeg_debug.log; then
        echo "✅ SUCCESS: Frames are being processed and sent"
        FRAME_COUNT=$(grep "frame=" ffmpeg_debug.log | tail -1 | sed 's/.*frame=\s*\([0-9]*\).*/\1/')
        echo "   Frames sent: $FRAME_COUNT"
    else
        echo "⚠️  UNKNOWN: Check debug log for details"
    fi
fi

echo ""
echo "5. System resource check..."
echo "=========================="
echo "CPU usage:"
top -bn1 | grep "Cpu(s)" | head -1
echo ""
echo "Memory usage:"
free -h
echo ""
echo "Network interfaces:"
ip addr show | grep -E "inet.*scope global"

echo ""
echo "Debug log saved to: ffmpeg_debug.log"
echo "Check this file for detailed FFmpeg output"
