#!/bin/bash

# YouTube Streaming - Matching OBS Settings Exactly
echo "🎥 YouTube Streaming - OBS Configuration Match"
echo "=============================================="

STREAM_KEY="3gpw-mdh2-6vwy-txb8-ebam"
RTMP_URL="rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY"

echo "Stream Key: $STREAM_KEY"
echo "RTMP URL: $RTMP_URL"
echo "Matching OBS: 1920x1080, x264, AAC audio"
echo ""

# Kill existing processes
pkill -f ffmpeg 2>/dev/null || true
sleep 2

# Start Xvfb with higher resolution to match OBS
if ! pgrep -f "Xvfb :99" > /dev/null; then
    echo "Starting Xvfb with 1920x1080 resolution..."
    pkill -f "Xvfb :99" 2>/dev/null || true
    Xvfb :99 -screen 0 1920x1080x24 -ac &
    sleep 3
fi

# Create bright blue test pattern
echo "Creating BRIGHT BLUE test pattern at 1920x1080..."
DISPLAY=:99 xsetroot -solid blue &

echo ""
echo "🚀 Starting OBS-matched stream for 60 seconds..."
echo "==============================================="
echo "Resolution: 1920x1080 (matching OBS)"
echo "Audio: AAC (matching OBS)"
echo "Encoder: x264 (matching OBS)"
echo ""

# OBS-matching FFmpeg command with audio
ffmpeg -f x11grab \
       -i ":99.0+0,0" \
       -f pulse \
       -i default \
       -s 1920x1080 \
       -r 30 \
       -c:v libx264 \
       -preset veryfast \
       -b:v 2500k \
       -maxrate 2500k \
       -bufsize 5000k \
       -pix_fmt yuv420p \
       -g 60 \
       -c:a aac \
       -b:a 128k \
       -ar 44100 \
       -f flv \
       "$RTMP_URL" \
       -t 60 \
       -y

echo ""
echo "✅ OBS-matched stream completed!"
echo "This should work exactly like OBS!"
echo "Check YouTube Studio for the BLUE 1920x1080 stream."
