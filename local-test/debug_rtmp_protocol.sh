#!/bin/bash

# RTMP Protocol Debug - Compare OBS vs FFmpeg
echo "🔍 RTMP Protocol Debugging"
echo "=========================="

STREAM_KEY="3gpw-mdh2-6vwy-txb8-ebam"
RTMP_URL="rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY"

echo "Testing RTMP handshake and metadata..."
echo ""

# Kill existing
pkill -f ffmpeg 2>/dev/null || true
sleep 2

# Setup display
if ! pgrep -f "Xvfb :99" > /dev/null; then
    Xvfb :99 -screen 0 1920x1080x24 -ac &
    sleep 3
fi

DISPLAY=:99 xsetroot -solid cyan &

echo "🚀 Testing with VERBOSE RTMP debugging..."
echo "========================================"

# FFmpeg with maximum RTMP debugging
ffmpeg -f x11grab \
       -i ":99.0+0,0" \
       -s 1920x1080 \
       -r 30 \
       -c:v libx264 \
       -profile:v high \
       -preset veryfast \
       -b:v 4500k \
       -minrate 4500k \
       -maxrate 4500k \
       -bufsize 9000k \
       -pix_fmt yuv420p \
       -g 60 \
       -keyint_min 60 \
       -sc_threshold 0 \
       -rtmp_live live \
       -rtmp_conn "S:flashVer=FMLE/3.0 (compatible; FMSc/1.0)" \
       -rtmp_conn "S:swfUrl=rtmp://a.rtmp.youtube.com/live2" \
       -rtmp_conn "S:tcUrl=rtmp://a.rtmp.youtube.com/live2" \
       -f flv \
       "$RTMP_URL" \
       -t 30 \
       -v debug \
       -report \
       -y 2>&1 | tee rtmp_detailed_debug.log

echo ""
echo "✅ Debug test completed!"
echo "Check rtmp_detailed_debug.log for RTMP handshake details"
echo ""
echo "🎯 Key things to check:"
echo "1. Does RTMP handshake complete successfully?"
echo "2. Are there any authentication errors?"
echo "3. Does YouTube accept the stream metadata?"
echo "4. Any specific error codes from YouTube?"
