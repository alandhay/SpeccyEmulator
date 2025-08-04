#!/bin/bash

# Verify YouTube Stream Status
echo "🔍 YouTube Stream Verification"
echo "=============================="

STREAM_KEY="v8s4-qp8m-xvw3-39z7-3dhm"

echo "Stream Key: $STREAM_KEY"
echo ""

echo "1. Checking if FFmpeg is still running..."
echo "========================================"
FFMPEG_PROCESSES=$(ps aux | grep ffmpeg | grep -v grep | wc -l)
echo "Active FFmpeg processes: $FFMPEG_PROCESSES"

if [ $FFMPEG_PROCESSES -gt 0 ]; then
    echo "FFmpeg processes:"
    ps aux | grep ffmpeg | grep -v grep
else
    echo "No FFmpeg processes running"
fi

echo ""
echo "2. Checking network connections to YouTube..."
echo "============================================="
netstat -an | grep :1935 | head -5

echo ""
echo "3. Testing YouTube RTMP endpoint directly..."
echo "============================================"
timeout 5 bash -c "echo 'test' | nc a.rtmp.youtube.com 1935" 2>/dev/null && echo "✅ RTMP endpoint reachable" || echo "❌ RTMP endpoint not reachable"

echo ""
echo "4. YouTube Studio Checklist:"
echo "============================"
echo "Please verify in YouTube Studio (https://studio.youtube.com):"
echo ""
echo "A. Go to 'Go Live' → 'Stream' tab"
echo "B. Check stream key matches: $STREAM_KEY"
echo "C. Look for stream status:"
echo "   - 'Ready to stream' = Waiting for connection"
echo "   - 'Starting' = Connection received, processing"
echo "   - 'Live' = Stream is active"
echo "D. If status shows 'Starting' or connected:"
echo "   - Click the 'GO LIVE' button"
echo "   - Set visibility to 'Public' if needed"
echo ""
echo "5. Common YouTube Issues:"
echo "========================"
echo "- Stream key expired: Generate new key"
echo "- Account restrictions: Check for live streaming blocks"
echo "- Wrong stream settings: Verify resolution/bitrate"
echo "- Manual activation needed: Must click 'GO LIVE' button"
echo ""
echo "6. Alternative test - Generate NEW stream key:"
echo "=============================================="
echo "If current key isn't working:"
echo "1. Go to YouTube Studio → Go Live → Stream"
echo "2. Click 'RESET STREAM KEY' or 'CREATE'"
echo "3. Copy the new key"
echo "4. Test with new key immediately"
