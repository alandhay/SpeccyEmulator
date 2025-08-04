#!/bin/bash

# YouTube Streaming - EXACT OBS Settings Match
echo "🎥 YouTube Streaming - EXACT OBS Configuration"
echo "=============================================="

STREAM_KEY="3gpw-mdh2-6vwy-txb8-ebam"
RTMP_URL="rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY"

echo "Stream Key: $STREAM_KEY"
echo "EXACT OBS Settings:"
echo "- Rate Control: CBR"
echo "- Bitrate: 4500 kbps"
echo "- Keyframe Interval: 2s"
echo "- Profile: High"
echo "- Tune: None"
echo "- Resolution: 1920x1080"
echo ""

# Kill existing processes
pkill -f ffmpeg 2>/dev/null || true
pkill -f "Xvfb :99" 2>/dev/null || true
sleep 2

# Start 1080p virtual display
echo "Starting 1920x1080 virtual display..."
Xvfb :99 -screen 0 1920x1080x24 -ac &
sleep 3

# Create bright magenta test pattern for visibility
echo "Creating BRIGHT MAGENTA test pattern at 1920x1080..."
DISPLAY=:99 xsetroot -solid magenta &

echo ""
echo "🚀 Starting EXACT OBS-matched stream for 60 seconds..."
echo "====================================================="

# EXACT OBS FFmpeg command
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
       -f flv \
       "$RTMP_URL" \
       -t 60 \
       -v info \
       -y

echo ""
echo "✅ EXACT OBS-matched stream completed!"
echo "Settings used:"
echo "- CBR: minrate=maxrate=4500k"
echo "- Keyframe: 60 frames (2s at 30fps)"
echo "- Profile: high"
echo "- No tune parameter"
echo ""
echo "This should work EXACTLY like your OBS setup!"
