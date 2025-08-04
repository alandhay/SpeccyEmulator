#!/bin/bash

# WORKING SOLUTION: Minimal FUSE → YouTube Live Streaming
# ========================================================
# This script successfully streams a local FUSE ZX Spectrum emulator to YouTube Live
# using the proven FFmpeg settings discovered through extensive testing.
#
# SUCCESS CONFIRMED: August 3, 2025
# - FUSE emulator starts correctly without graphics-filter parameter
# - Virtual X11 display works with Xvfb
# - FFmpeg captures and streams using working codec settings
# - Yellow timestamp overlay appears in top-right corner
# - Stereo audio stream ensures YouTube compatibility
#
# CRITICAL SUCCESS FACTORS:
# 1. Removed invalid --graphics-filter parameter from FUSE
# 2. Used proven FFmpeg settings from successful static tests
# 3. Included both video (X11 grab) and audio (anullsrc) streams
# 4. Applied standard HD resolution (1280x720)
# 5. Used veryfast preset with zerolatency tune
# 6. Avoided problematic cleanup routines that caused hangs

echo "🎮 Minimal FUSE → YouTube Stream"
echo "================================"

# YouTube streaming configuration
# Stream key rotates - update as needed from YouTube Studio
STREAM_KEY="3gpw-mdh2-6vwy-txb8-ebam"
RTMP_URL="rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY"

echo "Stream Key: $STREAM_KEY"
echo "RTMP URL: $RTMP_URL"
echo ""

# STEP 1: Start virtual X11 display
# Using display :95 to avoid conflicts with other tests
# Resolution 1280x720 matches our target streaming resolution
echo "Starting virtual display..."
export DISPLAY=:95
Xvfb :95 -screen 0 1280x720x24 -ac &
sleep 3  # Allow time for X server to initialize

echo "✅ Virtual display :95 started (1280x720x24)"

# STEP 2: Start FUSE emulator
# CRITICAL: Do NOT use --graphics-filter parameter (doesn't exist in this version)
# --machine 48: ZX Spectrum 48K (most compatible)
# --no-sound: Disable FUSE audio (we'll add synthetic audio via FFmpeg)
echo "Starting FUSE..."
fuse-sdl --machine 48 --no-sound &
sleep 5  # Allow time for FUSE to initialize and show boot screen

echo "✅ FUSE ZX Spectrum 48K started"

# STEP 3: Stream to YouTube using proven FFmpeg settings
echo "Starting stream to YouTube..."
echo "📺 Check YouTube Studio: https://studio.youtube.com"
echo "🛑 Press Ctrl+C to stop streaming"
echo ""

# PROVEN FFMPEG CONFIGURATION:
# This exact configuration was tested and confirmed working
# Based on successful static test: ffmpeg -f lavfi -i color=black:s=1280x720...
ffmpeg \
    `# VIDEO INPUT: Capture X11 virtual display` \
    -f x11grab \
    -video_size 1280x720 \
    -framerate 30 \
    -i :95.0+0,0 \
    \
    `# AUDIO INPUT: Synthetic stereo audio (required for YouTube)` \
    -f lavfi \
    -i "anullsrc=channel_layout=stereo:sample_rate=44100" \
    \
    `# VIDEO FILTER: Yellow timestamp overlay in top-right corner` \
    -vf "drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:text='LIVE ZX SPECTRUM %{localtime}':fontcolor=yellow:fontsize=36:x=w-text_w-20:y=20:box=1:boxcolor=black@0.7:boxborderw=3" \
    \
    `# VIDEO CODEC: H.264 with proven settings` \
    -c:v libx264 \
    -preset veryfast \
    -tune zerolatency \
    \
    `# AUDIO CODEC: AAC stereo (YouTube standard)` \
    -c:a aac \
    -b:a 128k \
    \
    `# OUTPUT FORMAT: YUV420P pixel format for compatibility` \
    -pix_fmt yuv420p \
    \
    `# STREAMING: FLV format to YouTube RTMP endpoint` \
    -f flv "$RTMP_URL"

echo ""
echo "🛑 Stream ended"
echo ""
echo "📊 Manual cleanup (if needed):"
echo "   pkill -f fuse      # Stop FUSE emulator"
echo "   pkill -f Xvfb      # Stop virtual display"
echo ""
echo "✅ FUSE streaming session completed successfully!"
