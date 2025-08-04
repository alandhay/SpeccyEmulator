#!/bin/bash

# YouTube Streaming - OBS-Style RTMP Parameters
echo "🎥 YouTube Streaming - OBS-Style RTMP"
echo "===================================="

STREAM_KEY="3gpw-mdh2-6vwy-txb8-ebam"

# Kill existing
pkill -f ffmpeg 2>/dev/null || true
sleep 2

if ! pgrep -f "Xvfb :99" > /dev/null; then
    Xvfb :99 -screen 0 1920x1080x24 -ac &
    sleep 3
fi

DISPLAY=:99 xsetroot -solid orange &

echo "🚀 Testing with OBS-style RTMP connection..."

# Try with OBS-style RTMP parameters
ffmpeg -f x11grab \
       -i ":99.0+0,0" \
       -s 1920x1080 \
       -r 30 \
       -c:v libx264 \
       -profile:v high \
       -level:v 4.0 \
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
       -rtmp_pageurl "https://www.youtube.com/" \
       -rtmp_swfurl "https://www.youtube.com/embed/live_stream" \
       -f flv \
       "rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY" \
       -t 45 \
       -y

echo "✅ OBS-style RTMP test completed!"
