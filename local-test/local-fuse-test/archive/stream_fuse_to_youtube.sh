#!/bin/bash

# Stream FUSE Emulator to YouTube Live
# Using proven FFmpeg settings from successful tests
echo "🎮 FUSE Emulator → YouTube Live Streaming"
echo "=========================================="

# Configuration
STREAM_KEY="3gpw-mdh2-6vwy-txb8-ebam"
RTMP_URL="rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY"
DISPLAY_NUM=":99"
FUSE_WINDOW_SIZE="256x192"
STREAM_SIZE="1280x720"

echo "Stream Key: $STREAM_KEY"
echo "RTMP URL: $RTMP_URL"
echo "Virtual Display: $DISPLAY_NUM"
echo "FUSE Window: $FUSE_WINDOW_SIZE"
echo "Stream Size: $STREAM_SIZE"
echo ""

# Clean up any existing processes
echo "🧹 Cleaning up existing processes..."
pkill -f fuse 2>/dev/null || true
pkill -f ffmpeg 2>/dev/null || true
pkill -f Xvfb 2>/dev/null || true
sleep 3

echo ""
echo "🖥️ Step 1: Starting virtual X11 display..."
echo "==========================================="

# Start virtual display for FUSE
export DISPLAY=$DISPLAY_NUM
Xvfb $DISPLAY_NUM -screen 0 1280x720x24 -ac +extension GLX &
XVFB_PID=$!
sleep 3

if ! pgrep -f "Xvfb $DISPLAY_NUM" > /dev/null; then
    echo "❌ Failed to start Xvfb virtual display!"
    exit 1
fi

echo "✅ Virtual display started (PID: $XVFB_PID)"

echo ""
echo "🎮 Step 2: Starting FUSE emulator..."
echo "===================================="

# Start FUSE emulator in background
echo "Starting FUSE with ZX Spectrum 48K..."
fuse-sdl --machine 48 --no-sound &
FUSE_PID=$!
sleep 5

if ! pgrep -f fuse-sdl > /dev/null; then
    echo "❌ Failed to start FUSE emulator!"
    kill $XVFB_PID 2>/dev/null || true
    exit 1
fi

echo "✅ FUSE emulator started (PID: $FUSE_PID)"
echo "🎯 FUSE should now be running and showing ZX Spectrum boot screen"

echo ""
echo "🎥 Step 3: Starting YouTube stream..."
echo "====================================="
echo ""
echo "Stream Configuration:"
echo "- Input: X11 screen capture from virtual display"
echo "- Audio: Synthetic stereo tone (FUSE audio disabled for stability)"
echo "- Video: Scale from ${FUSE_WINDOW_SIZE} to ${STREAM_SIZE}"
echo "- Codec: Your proven H.264 + AAC settings"
echo "- Overlay: Yellow timestamp in top-right"
echo ""
echo "📺 Check YouTube Studio NOW: https://studio.youtube.com"
echo "⏱️ Stream will run until you press Ctrl+C"
echo ""

# Stream FUSE emulator using proven settings
ffmpeg -f x11grab -video_size 1280x720 -framerate 30 -i $DISPLAY_NUM.0+0,0 \
       -f lavfi -i "anullsrc=channel_layout=stereo:sample_rate=44100" \
       -vf "scale=1280:720,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:text='🔴 LIVE ZX SPECTRUM %{localtime}':fontcolor=yellow:fontsize=36:x=w-text_w-20:y=20:box=1:boxcolor=black@0.7:boxborderw=3" \
       -c:v libx264 -preset veryfast -tune zerolatency \
       -c:a aac -b:a 128k \
       -pix_fmt yuv420p \
       -f flv "$RTMP_URL" \
       -v info

echo ""
echo "🛑 Stream ended or interrupted"
echo ""

# Cleanup function
cleanup() {
    echo "🧹 Cleaning up processes..."
    kill $FUSE_PID 2>/dev/null || true
    kill $XVFB_PID 2>/dev/null || true
    pkill -f ffmpeg 2>/dev/null || true
    echo "✅ Cleanup completed"
}

# Set trap for cleanup on script exit
trap cleanup EXIT

echo "📊 Stream Summary:"
echo "=================="
echo "✅ Used proven FFmpeg parameters from your working tests"
echo "✅ Captured full virtual display (1280x720)"
echo "✅ Added stereo audio stream for YouTube compatibility"
echo "✅ Applied yellow timestamp overlay"
echo "✅ Used your working codec settings"
echo ""
echo "🎯 What was streamed:"
echo "- FUSE ZX Spectrum 48K emulator"
echo "- Virtual display capture"
echo "- Live timestamp overlay"
echo "- Synthetic stereo audio"
echo ""
echo "💡 Next steps if this worked:"
echo "- Load games into FUSE (.tap, .tzx files)"
echo "- Enable FUSE audio output"
echo "- Add keyboard input handling"
echo "- Optimize display scaling"
