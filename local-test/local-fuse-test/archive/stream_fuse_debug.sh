#!/bin/bash

# Debug FUSE Emulator → YouTube Live Streaming
echo "🎮 FUSE Emulator → YouTube Live Streaming (Debug Version)"
echo "========================================================"

# Configuration
STREAM_KEY="3gpw-mdh2-6vwy-txb8-ebam"
RTMP_URL="rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY"
DISPLAY_NUM=":99"

echo "Stream Key: $STREAM_KEY"
echo "RTMP URL: $RTMP_URL"
echo "Virtual Display: $DISPLAY_NUM"
echo ""

# Quick cleanup
echo "🧹 Quick cleanup..."
pkill -9 -f fuse 2>/dev/null && echo "  Killed FUSE processes" || echo "  No FUSE processes to kill"
pkill -9 -f ffmpeg 2>/dev/null && echo "  Killed FFmpeg processes" || echo "  No FFmpeg processes to kill"
pkill -9 -f Xvfb 2>/dev/null && echo "  Killed Xvfb processes" || echo "  No Xvfb processes to kill"
sleep 2

echo ""
echo "🖥️ Starting virtual X11 display..."
export DISPLAY=$DISPLAY_NUM
echo "Command: Xvfb $DISPLAY_NUM -screen 0 1280x720x24 -ac +extension GLX"

Xvfb $DISPLAY_NUM -screen 0 1280x720x24 -ac +extension GLX &
XVFB_PID=$!
echo "Xvfb PID: $XVFB_PID"
sleep 3

# Check if Xvfb started
if pgrep -f "Xvfb $DISPLAY_NUM" > /dev/null; then
    echo "✅ Virtual display started successfully"
else
    echo "❌ Virtual display failed to start!"
    exit 1
fi

echo ""
echo "🎮 Starting FUSE emulator..."
echo "Command: fuse-sdl --machine 48 --no-sound"

fuse-sdl --machine 48 --no-sound &
FUSE_PID=$!
echo "FUSE PID: $FUSE_PID"
sleep 5

# Check if FUSE started
if pgrep -f fuse-sdl > /dev/null; then
    echo "✅ FUSE emulator started successfully"
    echo "Process info:"
    ps aux | grep fuse-sdl | grep -v grep
else
    echo "❌ FUSE failed to start!"
    echo "Checking for any error messages..."
    kill $XVFB_PID 2>/dev/null || true
    exit 1
fi

echo ""
echo "🎥 Testing FFmpeg capture first..."
echo "=================================="

# Test FFmpeg capture for 5 seconds first
echo "Testing X11 capture for 5 seconds..."
timeout 5s ffmpeg -f x11grab -video_size 1280x720 -framerate 30 -i $DISPLAY_NUM.0+0,0 \
       -f null - -v error 2>&1

CAPTURE_EXIT_CODE=$?
if [ $CAPTURE_EXIT_CODE -eq 124 ]; then
    echo "✅ X11 capture test successful (timeout reached)"
elif [ $CAPTURE_EXIT_CODE -eq 0 ]; then
    echo "✅ X11 capture test successful"
else
    echo "❌ X11 capture test failed with exit code: $CAPTURE_EXIT_CODE"
    echo "Cleaning up and exiting..."
    kill $FUSE_PID $XVFB_PID 2>/dev/null || true
    exit 1
fi

echo ""
echo "🚀 Starting YouTube stream..."
echo "============================="
echo ""
echo "📺 Check YouTube Studio: https://studio.youtube.com"
echo "⏱️ Stream will run for 30 seconds for testing"
echo "🛑 Press Ctrl+C to stop manually"
echo ""

# Stream with shorter timeout for testing
timeout 30s ffmpeg -f x11grab -video_size 1280x720 -framerate 30 -i $DISPLAY_NUM.0+0,0 \
       -f lavfi -i "anullsrc=channel_layout=stereo:sample_rate=44100" \
       -vf "drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:text='🔴 LIVE ZX SPECTRUM %{localtime}':fontcolor=yellow:fontsize=36:x=w-text_w-20:y=20:box=1:boxcolor=black@0.7:boxborderw=3" \
       -c:v libx264 -preset veryfast -tune zerolatency \
       -c:a aac -b:a 128k \
       -pix_fmt yuv420p \
       -f flv "$RTMP_URL" \
       -v info

STREAM_EXIT_CODE=$?

echo ""
echo "📊 Stream Results:"
echo "=================="
if [ $STREAM_EXIT_CODE -eq 124 ]; then
    echo "✅ Stream completed successfully (30-second timeout reached)"
elif [ $STREAM_EXIT_CODE -eq 0 ]; then
    echo "✅ Stream completed successfully"
else
    echo "⚠️ Stream ended with exit code: $STREAM_EXIT_CODE"
    case $STREAM_EXIT_CODE in
        1) echo "   → General FFmpeg error (check network/YouTube key)" ;;
        2) echo "   → Invalid arguments or configuration" ;;
        *) echo "   → Unknown error code" ;;
    esac
fi

echo ""
echo "🧹 Cleaning up..."
kill $FUSE_PID 2>/dev/null && echo "  FUSE stopped" || echo "  FUSE already stopped"
kill $XVFB_PID 2>/dev/null && echo "  Xvfb stopped" || echo "  Xvfb already stopped"
pkill -9 -f ffmpeg 2>/dev/null && echo "  FFmpeg stopped" || echo "  FFmpeg already stopped"

echo "✅ All processes cleaned up"
echo ""
echo "🎯 Next Steps:"
echo "=============="
if [ $STREAM_EXIT_CODE -eq 124 ] || [ $STREAM_EXIT_CODE -eq 0 ]; then
    echo "✅ Streaming is working! You can now:"
    echo "   → Run longer streams by increasing timeout"
    echo "   → Load games into FUSE"
    echo "   → Monitor YouTube Studio for viewer feedback"
else
    echo "❌ Streaming had issues. Check:"
    echo "   → YouTube stream key is valid and active"
    echo "   → Network connection to YouTube"
    echo "   → YouTube Studio for error messages"
fi
