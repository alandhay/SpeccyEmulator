#!/bin/bash

# Test YouTube RTMP Streaming Connection
# Stream Key: 0ebh-efdh-9qtq-2eq3-e6hz

echo "🎥 Testing YouTube RTMP Connection"
echo "=================================="

STREAM_KEY="0ebh-efdh-9qtq-2eq3-e6hz"
RTMP_URL="rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY"

echo "Stream Key: $STREAM_KEY"
echo "RTMP URL: $RTMP_URL"
echo ""

# Test with a simple color pattern for 30 seconds
echo "🧪 Testing RTMP connection with test pattern..."
echo "This will stream a test pattern to YouTube for 30 seconds"
echo "Check your YouTube Live dashboard to see if the stream appears"
echo ""

ffmpeg -f lavfi -i "testsrc2=size=320x240:rate=25" \
       -c:v libx264 -preset ultrafast -tune zerolatency \
       -b:v 2500k -maxrate 2500k -bufsize 5000k \
       -pix_fmt yuv420p -g 50 -keyint_min 25 \
       -f flv "$RTMP_URL" \
       -t 30 \
       -y

echo ""
echo "✅ Test stream completed!"
echo "Check your YouTube Studio Live dashboard to verify the connection worked."
echo ""
echo "If successful, you can now run the full emulator with:"
echo "  ./start_youtube_streaming.sh"
