#!/bin/bash

# Debug YouTube Streaming Issues
# Stream Key: 0ebh-efdh-9qtq-2eq3-e6hz

echo "🔍 YouTube Stream Debugging"
echo "=========================="

STREAM_KEY="0ebh-efdh-9qtq-2eq3-e6hz"
RTMP_URL="rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY"

echo "Stream Key: $STREAM_KEY"
echo "RTMP URL: $RTMP_URL"
echo ""

echo "1. Testing RTMP connection with verbose output..."
echo "================================================"

# Test with very verbose output to see what's happening
ffmpeg -f lavfi -i "color=blue:size=320x240:rate=25" \
       -vf "drawtext=text='DEBUG TEST $(date +%H:%M:%S)':fontcolor=white:fontsize=16:x=10:y=10" \
       -c:v libx264 -preset ultrafast -tune zerolatency \
       -b:v 2500k -maxrate 2500k -bufsize 5000k \
       -pix_fmt yuv420p -g 50 -keyint_min 25 \
       -f flv "$RTMP_URL" \
       -t 20 \
       -v verbose \
       -y 2>&1 | tee youtube_debug.log

echo ""
echo "2. Checking debug log for issues..."
echo "=================================="

if [ -f youtube_debug.log ]; then
    echo "Last 10 lines of debug output:"
    tail -10 youtube_debug.log
    echo ""
    
    # Check for common issues
    if grep -q "Connection refused" youtube_debug.log; then
        echo "❌ ISSUE: Connection refused - RTMP server not accepting connections"
    elif grep -q "403" youtube_debug.log; then
        echo "❌ ISSUE: 403 Forbidden - Stream key might be invalid or expired"
    elif grep -q "404" youtube_debug.log; then
        echo "❌ ISSUE: 404 Not Found - Stream endpoint not found"
    elif grep -q "Stream not found" youtube_debug.log; then
        echo "❌ ISSUE: Stream not found - Check stream key"
    elif grep -q "200" youtube_debug.log; then
        echo "✅ Connection successful (200) but stream not visible"
        echo "   This suggests the stream key is valid but YouTube isn't showing it"
    fi
fi

echo ""
echo "3. Possible Issues & Solutions:"
echo "=============================="
echo "If connection is successful but no video appears:"
echo ""
echo "A) YouTube Studio Setup:"
echo "   - Go to https://studio.youtube.com"
echo "   - Click 'Go Live' → 'Stream'"
echo "   - Make sure stream is set to 'Public' not 'Unlisted'"
echo "   - Click 'GO LIVE' button after stream connects"
echo ""
echo "B) Stream Key Issues:"
echo "   - Stream key might be expired"
echo "   - Generate a new stream key in YouTube Studio"
echo "   - Make sure you're using the correct key"
echo ""
echo "C) Account Issues:"
echo "   - YouTube channel needs to be verified for live streaming"
echo "   - Account needs to have no live streaming restrictions"
echo ""
echo "4. Next Steps:"
echo "============="
echo "1. Check YouTube Studio Live dashboard NOW"
echo "2. Look for stream status (should show 'Live' or 'Starting')"
echo "3. If stream shows as connected but no video, click 'GO LIVE'"
echo "4. If no stream appears at all, generate new stream key"

echo ""
echo "Debug log saved to: youtube_debug.log"
