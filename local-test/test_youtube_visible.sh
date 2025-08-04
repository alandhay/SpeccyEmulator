#!/bin/bash

# Visible YouTube RTMP Test with Clear Test Pattern
# Stream Key: 0ebh-efdh-9qtq-2eq3-e6hz

echo "🎥 YouTube Visibility Test - Clear Test Pattern"
echo "==============================================="

STREAM_KEY="0ebh-efdh-9qtq-2eq3-e6hz"
RTMP_URL="rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY"

echo "Stream Key: $STREAM_KEY"
echo "RTMP URL: $RTMP_URL"
echo ""
echo "🎨 Streaming BRIGHT test pattern with text for 60 seconds..."
echo "This should be VERY visible on your YouTube Live dashboard!"
echo ""
echo "Go to YouTube Studio → Go Live to see the stream"
echo "Press Ctrl+C to stop early if you see it working"
echo ""

# Create a very visible test pattern with text overlay
ffmpeg -f lavfi -i "testsrc2=size=320x240:rate=25" \
       -vf "drawtext=text='YOUTUBE TEST STREAM':fontcolor=white:fontsize=24:x=(w-text_w)/2:y=(h-text_h)/2:box=1:boxcolor=red@0.8:boxborderw=5,drawtext=text='Stream Key\: 0ebh-efdh-9qtq-2eq3-e6hz':fontcolor=yellow:fontsize=12:x=10:y=h-30:box=1:boxcolor=black@0.8" \
       -c:v libx264 -preset ultrafast -tune zerolatency \
       -b:v 2500k -maxrate 2500k -bufsize 5000k \
       -pix_fmt yuv420p -g 50 -keyint_min 25 \
       -f flv "$RTMP_URL" \
       -t 60 \
       -y

echo ""
echo "✅ Visible test stream completed!"
echo ""
echo "Did you see the test pattern on YouTube? It should have shown:"
echo "  - Colorful moving test pattern"
echo "  - Large white text: 'YOUTUBE TEST STREAM'"
echo "  - Your stream key at the bottom"
echo ""
echo "If you saw it: ✅ YouTube streaming is working!"
echo "If not: ❌ Check YouTube Studio Live dashboard or stream key"
