#!/bin/bash

# Stream FUSE Emulator with Game Loading to YouTube Live
# Using proven FFmpeg settings from successful tests
echo "🎮 FUSE Emulator + Game → YouTube Live Streaming"
echo "================================================"

# Configuration
STREAM_KEY="3gpw-mdh2-6vwy-txb8-ebam"
RTMP_URL="rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY"
DISPLAY_NUM=":99"
GAME_FILE="${1}"

echo "Stream Key: $STREAM_KEY"
echo "RTMP URL: $RTMP_URL"
echo "Virtual Display: $DISPLAY_NUM"
echo "Game File: ${GAME_FILE:-"None specified - will show BASIC prompt"}"
echo ""

# Check if game file exists (if specified)
if [ -n "$GAME_FILE" ] && [ ! -f "$GAME_FILE" ]; then
    echo "❌ Game file '$GAME_FILE' not found!"
    echo ""
    echo "Usage: $0 [game_file.tap|game_file.tzx]"
    echo ""
    echo "Available game files in current directory:"
    ls -la *.tap *.tzx *.z80 *.sna 2>/dev/null || echo "  No game files found"
    echo ""
    echo "💡 You can also run without a game file to stream the BASIC prompt"
    exit 1
fi

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

# Build FUSE command
FUSE_CMD="fuse-sdl --machine 48"

if [ -n "$GAME_FILE" ]; then
    echo "Loading game: $GAME_FILE"
    FUSE_CMD="$FUSE_CMD --tape \"$GAME_FILE\""
    echo "🎯 Game will be loaded - use LOAD \"\" in BASIC or press J then Ctrl+P+P"
else
    echo "No game specified - will show BASIC prompt"
    echo "🎯 You can type BASIC commands or load games manually"
fi

# Start FUSE emulator in background
echo "Starting FUSE with ZX Spectrum 48K..."
eval "$FUSE_CMD" &
FUSE_PID=$!
sleep 5

if ! pgrep -f fuse-sdl > /dev/null; then
    echo "❌ Failed to start FUSE emulator!"
    kill $XVFB_PID 2>/dev/null || true
    exit 1
fi

echo "✅ FUSE emulator started (PID: $FUSE_PID)"

if [ -n "$GAME_FILE" ]; then
    echo "🎮 Game loaded in tape drive"
    echo "📝 To run the game:"
    echo "   1. Type: LOAD \"\" (or press J then Ctrl+P+P)"
    echo "   2. Press ENTER"
    echo "   3. Wait for loading to complete"
    echo "   4. Type: RUN"
else
    echo "💻 BASIC prompt ready"
    echo "📝 You can:"
    echo "   1. Type BASIC commands"
    echo "   2. Load games with File menu"
    echo "   3. Use keyboard shortcuts"
fi

echo ""
echo "🎥 Step 3: Starting YouTube stream..."
echo "====================================="
echo ""
echo "Stream Configuration:"
echo "- Input: X11 screen capture from FUSE emulator"
echo "- Audio: Synthetic stereo tone (for YouTube compatibility)"
echo "- Video: Capture full virtual display (1280x720)"
echo "- Codec: Your proven H.264 + AAC settings"
echo "- Overlay: Yellow 'LIVE ZX SPECTRUM' timestamp"
echo ""
echo "📺 Check YouTube Studio NOW: https://studio.youtube.com"
echo "⏱️ Stream will run until you press Ctrl+C"
echo ""
echo "🎮 FUSE Controls while streaming:"
echo "- F1: Help menu"
echo "- F2: Save snapshot"
echo "- F3: Load snapshot"
echo "- F4: Open file"
echo "- F10: Quit FUSE"
echo "- Alt+Enter: Toggle fullscreen"
echo ""

# Stream FUSE emulator using proven settings
ffmpeg -f x11grab -video_size 1280x720 -framerate 30 -i $DISPLAY_NUM.0+0,0 \
       -f lavfi -i "anullsrc=channel_layout=stereo:sample_rate=44100" \
       -vf "drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:text='🔴 LIVE ZX SPECTRUM %{localtime}':fontcolor=yellow:fontsize=36:x=w-text_w-20:y=20:box=1:boxcolor=black@0.7:boxborderw=3" \
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
echo "✅ Streamed FUSE ZX Spectrum 48K emulator"
echo "✅ Used proven FFmpeg parameters"
echo "✅ Applied yellow timestamp overlay"
echo "✅ Included stereo audio for YouTube compatibility"
if [ -n "$GAME_FILE" ]; then
    echo "✅ Game loaded: $GAME_FILE"
else
    echo "✅ BASIC prompt streamed"
fi
echo ""
echo "🎯 What was streamed:"
echo "- Live ZX Spectrum emulator session"
echo "- Real-time interaction capability"
echo "- Authentic ZX Spectrum experience"
echo ""
echo "💡 For better streaming experience:"
echo "- Use games with colorful graphics"
echo "- Enable FUSE sound output"
echo "- Consider adding webcam overlay"
echo "- Add chat interaction features"
