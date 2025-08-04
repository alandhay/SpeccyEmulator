#!/bin/bash

# Minimal YouTube RTMP Test - No fancy filters
# Stream Key: 0ebh-efdh-9qtq-2eq3-e6hz

echo "🎯 Minimal YouTube Test"
echo "======================"

STREAM_KEY="0ebh-efdh-9qtq-2eq3-e6hz"
RTMP_URL="rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY"

echo "Stream Key: $STREAM_KEY"
echo "RTMP URL: $RTMP_URL"
echo ""
echo "🔴 Streaming solid RED screen for 20 seconds..."
echo "Check YouTube Studio NOW - should see red screen!"
echo ""

# Absolute minimal test - just a red screen, no text, no complications
ffmpeg -f lavfi -i "color=red:size=320x240:rate=25" \
       -c:v libx264 -preset ultrafast \
       -b:v 2500k -maxrate 2500k -bufsize 5000k \
       -pix_fmt yuv420p \
       -f flv "$RTMP_URL" \
       -t 20 \
       -y

echo ""
echo "Test completed. Did you see a red screen on YouTube?"
