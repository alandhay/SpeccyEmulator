#!/bin/bash

# Static Image YouTube Test - Very Easy to Spot
# Stream Key: 0ebh-efdh-9qtq-2eq3-e6hz

echo "🖼️  YouTube Static Image Test"
echo "============================"

STREAM_KEY="0ebh-efdh-9qtq-2eq3-e6hz"
RTMP_URL="rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY"

echo "Stream Key: $STREAM_KEY"
echo "RTMP URL: $RTMP_URL"
echo ""
echo "📺 Streaming STATIC RED SCREEN with text for 45 seconds..."
echo "This will be a solid red background - impossible to miss!"
echo ""
echo "Go to YouTube Studio → Go Live NOW to see the stream"
echo "Press Ctrl+C to stop early if you see it working"
echo ""

# Create a solid red background with large white text
ffmpeg -f lavfi -i "color=red:size=320x240:rate=25" \
       -vf "drawtext=text='YOUTUBE LIVE TEST':fontcolor=white:fontsize=20:x=(w-text_w)/2:y=60:box=1:boxcolor=black@0.8:boxborderw=3,drawtext=text='ZX SPECTRUM EMULATOR':fontcolor=white:fontsize=16:x=(w-text_w)/2:y=120:box=1:boxcolor=black@0.8,drawtext=text='Stream Working!':fontcolor=yellow:fontsize=14:x=(w-text_w)/2:y=180:box=1:boxcolor=blue@0.8" \
       -c:v libx264 -preset ultrafast -tune zerolatency \
       -b:v 2500k -maxrate 2500k -bufsize 5000k \
       -pix_fmt yuv420p -g 50 -keyint_min 25 \
       -f flv "$RTMP_URL" \
       -t 45 \
       -y

echo ""
echo "✅ Static image test completed!"
echo ""
echo "Results:"
echo "  ✅ If you saw a RED SCREEN with white text → YouTube streaming works!"
echo "  ❌ If you saw nothing → Check YouTube Studio or stream key issue"
echo ""
echo "Next step: If this worked, run the full emulator with YouTube streaming!"
