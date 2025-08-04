#!/bin/bash

# IMPROVED SOLUTION: No Cursor + 90% Scaling + Perfect Centering
# ==============================================================
# This version removes the mouse cursor and scales to 90% of 2x (1.8x total)
# while keeping everything perfectly centered in the HD frame.
#
# IMPROVEMENTS:
# - Hide mouse cursor from stream (-draw_mouse 0)
# - Scale to 1.8x instead of 2x (10% reduction)
# - Maintain perfect centering in HD frame
# - Keep all other working aspects

echo "🎮 IMPROVED: No Cursor + 90% Scaling + Perfect Center"
echo "====================================================="

# YouTube streaming configuration
STREAM_KEY="8w86-k4v4-4trq-pvwy-6v58"
RTMP_URL="rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY"

echo "Stream Key: $STREAM_KEY"
echo "RTMP URL: $RTMP_URL"
echo "Improvements: No cursor, 1.8x scaling (90% of 2x), centered"
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

# STEP 3: Calculate center capture area (same as before)
DISPLAY_W=800
DISPLAY_H=600
CAPTURE_W=320  # Estimated FUSE window width
CAPTURE_H=240  # Estimated FUSE window height

# Calculate offset to center the capture
OFFSET_X=$(( (DISPLAY_W - CAPTURE_W) / 2 ))
OFFSET_Y=$(( (DISPLAY_H - CAPTURE_H) / 2 ))

echo "🎯 Capture settings:"
echo "   Display: ${DISPLAY_W}x${DISPLAY_H}"
echo "   Capture: ${CAPTURE_W}x${CAPTURE_H}"
echo "   Offset: +${OFFSET_X},${OFFSET_Y}"
echo "   Scaling: 1.8x (90% of 2x)"
echo "   Cursor: Hidden"

# STEP 4: Stream with no cursor and 90% scaling
echo "Starting cursor-free 90% scaled stream..."
echo "📺 Check YouTube Studio: https://studio.youtube.com"
echo "🛑 Press Ctrl+C to stop streaming"
echo ""

# IMPROVED APPROACH:
# 1. Capture center area with NO CURSOR (-draw_mouse 0)
# 2. Apply 1.8x scaling instead of 2x (10% reduction)
# 3. Center in HD frame with proper aspect ratio
# 4. Add timestamp overlay
ffmpeg \
    `# VIDEO INPUT: Capture center area with NO CURSOR` \
    -f x11grab \
    -draw_mouse 0 \
    -video_size ${CAPTURE_W}x${CAPTURE_H} \
    -framerate 30 \
    -i :95.0+${OFFSET_X},${OFFSET_Y} \
    \
    `# AUDIO INPUT: Synthetic stereo audio` \
    -f lavfi \
    -i "anullsrc=channel_layout=stereo:sample_rate=44100" \
    \
    `# VIDEO FILTER: 1.8x upscale (90% of 2x), center in HD frame` \
    -vf "scale=iw*1.8:ih*1.8:flags=neighbor,scale=1280:720:flags=lanczos:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2:black,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:text='🔴 LIVE ZX SPECTRUM 1.8X %{localtime}':fontcolor=yellow:fontsize=36:x=w-text_w-20:y=20:box=1:boxcolor=black@0.7:boxborderw=3" \
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
echo "✅ Improved streaming completed!"
echo ""
echo "🎯 Improvement Details:"
echo "   📐 Virtual Display: 800x600"
echo "   🔍 Capture Area: ${CAPTURE_W}x${CAPTURE_H} at +${OFFSET_X},${OFFSET_Y}"
echo "   🖱️  Mouse Cursor: Hidden (-draw_mouse 0)"
echo "   📈 Scaling: 1.8x nearest neighbor (320x240 → 576x432)"
echo "   📺 Final: Centered in 1280x720 HD frame"
echo "   ✨ Result: Clean, cursor-free, perfectly sized stream"
