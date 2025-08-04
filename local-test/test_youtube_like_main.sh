#!/bin/bash

# Test YouTube streaming exactly like the main program does
echo "🎥 YouTube Test - Main Program Style"
echo "===================================="

# Use your current active stream key
STREAM_KEY="v8s4-qp8m-xvw3-39z7-3dhm"
RTMP_URL="rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY"

echo "Stream Key: $STREAM_KEY"
echo "RTMP URL: $RTMP_URL"
echo ""

echo "🔧 Testing with EXACT main program FFmpeg settings..."
echo "====================================================="

# Use the EXACT FFmpeg parameters from your main program
ffmpeg -f lavfi -i "color=red:size=320x240:rate=25" \
       -c:v libx264 -preset ultrafast -tune zerolatency \
       -b:v 2500k -maxrate 2500k -bufsize 5000k \
       -pix_fmt yuv420p -g 50 -keyint_min 25 \
       -f flv "$RTMP_URL" \
       -t 45 \
       -v info \
       -y

echo ""
echo "✅ Test completed!"
echo ""
echo "If this worked, the issue was FFmpeg parameters."
echo "If this failed, the issue is YouTube stream key/account setup."
echo ""
echo "Next: Check YouTube Studio → Go Live → Stream tab"
echo "Look for stream status and click 'GO LIVE' if needed."
