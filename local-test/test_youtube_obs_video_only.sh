#!/bin/bash

# YouTube Streaming - OBS Video Settings Only
echo "🎥 YouTube Streaming - OBS Video Match (No Audio)"
echo "================================================"

STREAM_KEY="3gpw-mdh2-6vwy-txb8-ebam"
RTMP_URL="rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY"

# Kill existing and setup 1080p display
pkill -f ffmpeg 2>/dev/null || true
pkill -f "Xvfb :99" 2>/dev/null || true
sleep 2

echo "Starting 1920x1080 virtual display..."
Xvfb :99 -screen 0 1920x1080x24 -ac &
sleep 3

# Bright red pattern for 1080p
DISPLAY=:99 xsetroot -solid red &

echo "🚀 Streaming 1920x1080 RED pattern (OBS video settings)..."

# OBS video settings without audio
ffmpeg -f x11grab \
       -i ":99.0+0,0" \
       -s 1920x1080 \
       -r 30 \
       -c:v libx264 \
       -preset veryfast \
       -b:v 2500k \
       -maxrate 2500k \
       -bufsize 5000k \
       -pix_fmt yuv420p \
       -g 60 \
       -f flv \
       "$RTMP_URL" \
       -t 60 \
       -y

echo "✅ 1080p video-only stream completed!"
