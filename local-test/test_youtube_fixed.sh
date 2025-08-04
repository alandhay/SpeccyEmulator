#!/bin/bash

# Fixed YouTube RTMP Test
# Stream Key: 0ebh-efdh-9qtq-2eq3-e6hz

echo "🔧 Fixed YouTube RTMP Test"
echo "=========================="

STREAM_KEY="0ebh-efdh-9qtq-2eq3-e6hz"
RTMP_URL="rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY"

echo "Stream Key: $STREAM_KEY"
echo "RTMP URL: $RTMP_URL"
echo ""
echo "🎥 Streaming FIXED test pattern for 30 seconds..."
echo "Monitor YouTube Studio NOW!"
echo ""

# Simple test without complex text overlay that was causing the error
ffmpeg -f lavfi -i "testsrc2=size=320x240:rate=25" \
       -c:v libx264 -preset ultrafast -tune zerolatency \
       -b:v 2500k -maxrate 2500k -bufsize 5000k \
       -pix_fmt yuv420p -g 50 -keyint_min 25 \
       -f flv "$RTMP_URL" \
       -t 30 \
       -v info \
       -y

echo ""
echo "✅ Test completed!"
echo "Did you see the colorful test pattern on YouTube Studio?"
