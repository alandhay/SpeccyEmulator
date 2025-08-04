#!/bin/bash

# Test YouTube Backup RTMP Endpoint
echo "🔄 Testing YouTube Backup Endpoint"
echo "=================================="

STREAM_KEY="3gpw-mdh2-6vwy-txb8-ebam"
BACKUP_URL="rtmp://b.rtmp.youtube.com/live2/$STREAM_KEY?backup=1"

echo "Using BACKUP endpoint: $BACKUP_URL"
echo ""

# Kill existing and setup display
pkill -f ffmpeg 2>/dev/null || true
sleep 2

if ! pgrep -f "Xvfb :99" > /dev/null; then
    Xvfb :99 -screen 0 320x240x24 -ac &
    sleep 3
fi

# Red pattern for backup test
DISPLAY=:99 xsetroot -solid red &

echo "🚀 Testing BACKUP endpoint with RED pattern..."
ffmpeg -f x11grab -i ":99.0+0,0" -s 320x240 -r 30 \
       -c:v libx264 -preset ultrafast -tune zerolatency \
       -b:v 1500k -maxrate 1500k -bufsize 3000k \
       -pix_fmt yuv420p -g 30 -keyint_min 15 \
       -f flv "$BACKUP_URL" -t 60 -y

echo "✅ Backup endpoint test completed!"
