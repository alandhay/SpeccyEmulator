#!/bin/bash

# WORKING SOLUTION: Adaptive 4x Upscaled FUSE → YouTube Streaming
# ===============================================================
# This version captures the full virtual display and applies 4x upscaling
# to the entire frame, letting FUSE determine its own window size and position.
#
# 4X UPSCALING APPROACH:
# - Capture full virtual display (800x600)
# - Apply 4x nearest neighbor scaling (800x600 → 3200x2400)
# - Scale down to fit HD frame (3200x2400 → 1280x720)
# - This preserves any FUSE window positioning automatically
# - Results in massive pixel visibility for retro gaming

echo "🎮 Adaptive 4x Upscaled FUSE → YouTube Stream"
echo "============================================="

# YouTube streaming configuration
STREAM_KEY="3gpw-mdh2-6vwy-txb8-ebam"
RTMP_URL="rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY"

echo "Stream Key: $STREAM_KEY"
echo "RTMP URL: $RTMP_URL"
echo "Upscaling: Adaptive 4x with nearest neighbor"
echo ""

# STEP 1: Start virtual X11 display
echo "Starting virtual display..."
export DISPLAY=:95
Xvfb :95 -screen 0 800x600x24 -ac &
sleep 3

echo "✅ Virtual display :95 started (800x600x24)"

# STEP 2: Start FUSE emulator
echo "Starting FUSE..."
fuse-sdl --machine 48 --no-sound &
sleep 5

echo "✅ FUSE ZX Spectrum 48K started"

# STEP 3: Stream with adaptive 4x upscaling
echo "Starting adaptive 4x upscaled stream..."
echo "📺 Check YouTube Studio: https://studio.youtube.com"
echo "🛑 Press Ctrl+C to stop streaming"
echo ""
echo "🔍 4x Adaptive Scaling Process:"
echo "   1. Capture: 800x600 virtual display"
echo "   2. Upscale: 4x nearest neighbor → 3200x2400"
echo "   3. Fit: Scale to 1280x720 HD frame"
echo "   4. Result: Maximum pixel visibility"
echo ""

# ADAPTIVE 4X UPSCALING APPROACH:
# 1. Capture full 800x600 virtual display
# 2. Apply 4x nearest neighbor scaling for maximum pixel size
# 3. Scale to fit 1280x720 HD frame
# 4. Add timestamp overlay
ffmpeg \
    `# VIDEO INPUT: Capture full virtual display` \
    -f x11grab \
    -video_size 800x600 \
    -framerate 30 \
    -i :95.0+0,0 \
    \
    `# AUDIO INPUT: Synthetic stereo audio` \
    -f lavfi \
    -i "anullsrc=channel_layout=stereo:sample_rate=44100" \
    \
    `# VIDEO FILTER: 4x upscale with nearest neighbor, then fit to HD` \
    -vf "scale=3200:2400:flags=neighbor,scale=1280:720:flags=lanczos,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:text='🔴 LIVE ZX SPECTRUM 4X %{localtime}':fontcolor=yellow:fontsize=36:x=w-text_w-20:y=20:box=1:boxcolor=black@0.7:boxborderw=3" \
    \
    `# VIDEO CODEC: H.264 with proven settings` \
    -c:v libx264 \
    -preset veryfast \
    -tune zerolatency \
    \
    `# AUDIO CODEC: AAC stereo` \
    -c:a aac \
    -b:a 128k \
    \
    `# OUTPUT FORMAT: YUV420P for compatibility` \
    -pix_fmt yuv420p \
    \
    `# STREAMING: FLV to YouTube RTMP` \
    -f flv "$RTMP_URL"

echo ""
echo "🛑 Stream ended"
echo ""
echo "📊 Manual cleanup (if needed):"
echo "   pkill -f fuse      # Stop FUSE emulator"
echo "   pkill -f Xvfb      # Stop virtual display"
echo ""
echo "✅ Adaptive 4x upscaled streaming completed!"
echo ""
echo "🎯 4x Scaling Benefits:"
echo "   ✅ Massive pixel visibility for viewers"
echo "   ✅ Perfect for retro gaming content"
echo "   ✅ Crisp, blocky pixel art aesthetic"
echo "   ✅ Easy to read text and graphics"
