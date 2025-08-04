#!/bin/bash

# Test YouTube streaming exactly like working server
echo "🎥 YouTube Test - Exact Server Match with X11"
echo "=============================================="

STREAM_KEY="v8s4-qp8m-xvw3-39z7-3dhm"
DISPLAY=":99"

echo "Stream Key: $STREAM_KEY"
echo "Display: $DISPLAY"
echo ""

# 1. Start Xvfb (virtual display) like the server does
echo "1. Starting virtual X11 display..."
Xvfb :99 -screen 0 320x240x24 -ac &
XVFB_PID=$!
echo "Xvfb started with PID: $XVFB_PID"

# Wait for Xvfb to start
sleep 3

# 2. Put something on the display (optional - creates a pattern)
echo "2. Creating test pattern on display..."
DISPLAY=:99 xsetroot -solid red &

# 3. Run FFmpeg with EXACT server parameters
echo "3. Starting FFmpeg with exact server parameters..."
echo "=================================================="

ffmpeg -f x11grab \
       -i ":99.0+0,0" \
       -s 320x240 \
       -r 25 \
       -c:v libx264 \
       -preset fast \
       -b:v 2500k \
       -maxrate 2500k \
       -bufsize 5000k \
       -f flv \
       "rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY" \
       -t 30 \
       -y

echo ""
echo "4. Cleaning up..."
echo "================"
kill $XVFB_PID 2>/dev/null
echo "Xvfb stopped"

echo ""
echo "✅ Test completed!"
echo "This should work exactly like your main server."
echo "Check YouTube Studio for the red screen!"
