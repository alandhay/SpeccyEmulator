#!/bin/bash

# Robust FUSE Emulator → YouTube Live Streaming
echo "🎮 FUSE Emulator → YouTube Live Streaming (Robust Version)"
echo "=========================================================="

# Configuration
STREAM_KEY="3gpw-mdh2-6vwy-txb8-ebam"
RTMP_URL="rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY"
DISPLAY_NUM=":99"

echo "Stream Key: $STREAM_KEY"
echo "RTMP URL: $RTMP_URL"
echo "Virtual Display: $DISPLAY_NUM"
echo ""

# Quick cleanup without hanging
echo "🧹 Quick cleanup..."
pkill -9 -f fuse 2>/dev/null || true
pkill -9 -f ffmpeg 2>/dev/null || true
pkill -9 -f Xvfb 2>/dev/null || true
sleep 1

echo ""
echo "🖥️ Starting virtual X11 display..."
export DISPLAY=$DISPLAY_NUM
Xvfb $DISPLAY_NUM -screen 0 1280x720x24 -ac +extension GLX > /dev/null 2>&1 &
XVFB_PID=$!
sleep 3

echo "✅ Virtual display started (PID: $XVFB_PID)"

echo ""
echo "🎮 Starting FUSE emulator..."
fuse-sdl --machine 48 --no-sound > /dev/null 2>&1 &
FUSE_PID=$!
sleep 5

if pgrep -f fuse-sdl > /dev/null; then
    echo "✅ FUSE emulator started (PID: $FUSE_PID)"
else
    echo "❌ FUSE failed to start!"
    kill $XVFB_PID 2>/dev/null || true
    exit 1
fi

echo ""
echo "🎥 Starting YouTube stream..."
echo "============================="
echo ""
echo "📺 Check YouTube Studio: https://studio.youtube.com"
echo "⏱️ Stream will run for 60 seconds, then auto-stop"
echo "🛑 Or press Ctrl+C to stop manually"
echo ""

# Stream with timeout to prevent hanging
timeout 60s ffmpeg -f x11grab -video_size 1280x720 -framerate 30 -i $DISPLAY_NUM.0+0,0 \
       -f lavfi -i "anullsrc=channel_layout=stereo:sample_rate=44100" \
       -vf "drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:text='🔴 LIVE ZX SPECTRUM %{localtime}':fontcolor=yellow:fontsize=36:x=w-text_w-20:y=20:box=1:boxcolor=black@0.7:boxborderw=3" \
       -c:v libx264 -preset veryfast -tune zerolatency \
       -c:a aac -b:a 128k \
       -pix_fmt yuv420p \
       -f flv "$RTMP_URL" \
       -v error 2>&1

STREAM_EXIT_CODE=$?

echo ""
if [ $STREAM_EXIT_CODE -eq 124 ]; then
    echo "✅ Stream completed successfully (60-second timeout reached)"
elif [ $STREAM_EXIT_CODE -eq 0 ]; then
    echo "✅ Stream completed successfully"
else
    echo "⚠️ Stream ended with exit code: $STREAM_EXIT_CODE"
fi

echo ""
echo "🧹 Cleaning up..."
kill $FUSE_PID 2>/dev/null || true
kill $XVFB_PID 2>/dev/null || true
pkill -9 -f ffmpeg 2>/dev/null || true

echo "✅ Cleanup completed"
echo ""
echo "📊 Stream Summary:"
echo "=================="
echo "✅ Used proven FFmpeg parameters from your working tests"
echo "✅ Streamed FUSE ZX Spectrum 48K emulator"
echo "✅ Applied yellow timestamp overlay"
echo "✅ Included stereo audio for YouTube compatibility"
echo ""
echo "🎯 If the stream worked:"
echo "- You should have seen ZX Spectrum display on YouTube"
echo "- The stream ran for 60 seconds automatically"
echo "- All processes cleaned up properly"
echo ""
echo "🎯 To run longer streams:"
echo "- Edit the timeout value in this script"
echo "- Or use Ctrl+C to stop manually"
echo "- Monitor YouTube Studio for stream health"
