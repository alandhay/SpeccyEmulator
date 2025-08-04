#!/bin/bash

# Test YouTube Low Latency Streaming
echo "🎥 Testing YouTube Low Latency Configuration"
echo "============================================"

STREAM_KEY="3gpw-mdh2-6vwy-txb8-ebam"
PRIMARY_URL="rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY"
BACKUP_URL="rtmp://b.rtmp.youtube.com/live2/$STREAM_KEY?backup=1"

echo "Stream Key: $STREAM_KEY"
echo "Primary URL: $PRIMARY_URL"
echo "Backup URL: $BACKUP_URL"
echo ""

# Kill any existing streams
pkill -f ffmpeg 2>/dev/null || true
sleep 2

# Start Xvfb if needed
if ! pgrep -f "Xvfb :99" > /dev/null; then
    echo "Starting Xvfb..."
    Xvfb :99 -screen 0 320x240x24 -ac &
    sleep 3
fi

# Create bright green test pattern for visibility
echo "Creating BRIGHT GREEN test pattern..."
DISPLAY=:99 xsetroot -solid green &

echo ""
echo "🚀 Starting LOW LATENCY stream for 60 seconds..."
echo "==============================================="
echo "Check YouTube Studio for the stream!"
echo "https://studio.youtube.com → Go Live → Stream"
echo ""

# Low latency optimized FFmpeg command
ffmpeg -f x11grab \
       -i ":99.0+0,0" \
       -s 320x240 \
       -r 30 \
       -c:v libx264 \
       -preset ultrafast \
       -tune zerolatency \
       -b:v 1500k \
       -maxrate 1500k \
       -bufsize 3000k \
       -pix_fmt yuv420p \
       -g 30 \
       -keyint_min 15 \
       -sc_threshold 0 \
       -f flv \
       "$PRIMARY_URL" \
       -t 60 \
       -v info \
       -y

echo ""
echo "✅ Low latency stream completed!"
echo "Did you see the GREEN screen in YouTube Studio?"
echo ""
echo "If it didn't appear, we can try the backup endpoint next."
