#!/bin/bash

# Simplest Possible YouTube Stream Test
echo "🎥 Simplest YouTube Stream Test"
echo "==============================="

STREAM_KEY="3gpw-mdh2-6vwy-txb8-ebam"

# Kill existing
pkill -f ffmpeg 2>/dev/null || true
sleep 2

# Use system display instead of virtual
echo "Using system display instead of virtual..."
echo "Creating test pattern..."

# Create a simple test video file first
ffmpeg -f lavfi -i testsrc2=size=1920x1080:rate=30 \
       -f lavfi -i sine=frequency=1000:sample_rate=44100 \
       -c:v libx264 -profile:v high -preset veryfast \
       -b:v 4500k -minrate 4500k -maxrate 4500k \
       -c:a aac -b:a 128k \
       -pix_fmt yuv420p -g 60 \
       -t 30 test_pattern.mp4 -y

echo ""
echo "🚀 Streaming pre-made test file to YouTube..."
echo "============================================="

# Stream the file instead of live capture
ffmpeg -re -i test_pattern.mp4 \
       -c copy \
       -f flv \
       "rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY" \
       -v info

echo ""
echo "✅ File-based stream test completed!"
echo "This eliminates X11/capture issues and tests pure RTMP"
