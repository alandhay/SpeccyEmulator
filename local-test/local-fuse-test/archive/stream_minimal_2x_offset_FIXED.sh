#!/bin/bash

# SIMPLE SOLUTION: Offset Capture for Centering
# ==============================================
# This version simply adjusts the capture offset to center the FUSE window
# in your existing 800x600 virtual display setup.
#
# OFFSET APPROACH:
# - Keep your existing 800x600 virtual display
# - Calculate offset to capture center area containing FUSE
# - Apply 2x scaling to the captured center area
# - Center result in HD frame

echo "🎮 SIMPLE: Offset Capture for Centering"
echo "======================================="

# YouTube streaming configuration
STREAM_KEY="3gpw-mdh2-6vwy-txb8-ebam"
RTMP_URL="rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY"

echo "Stream Key: $STREAM_KEY"
echo "RTMP URL: $RTMP_URL"
echo "Approach: Center capture with calculated offset"
echo ""

# STEP 1: Start virtual X11 display (same as your original)
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

# STEP 3: Calculate center capture area
# Assuming FUSE creates a ~320x240 window, we want to capture a centered area
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

# STEP 4: Stream with centered offset capture
echo "Starting offset-centered stream..."
echo "📺 Check YouTube Studio: https://studio.youtube.com"
echo "🛑 Press Ctrl+C to stop streaming"
echo ""

# OFFSET CAPTURE APPROACH:
# 1. Capture center area of virtual display where FUSE should be
# 2. Apply 2x nearest neighbor scaling
# 3. Center in HD frame with proper aspect ratio
# 4. Add timestamp overlay
ffmpeg \
    `# VIDEO INPUT: Capture center area with calculated offset` \
    -f x11grab \
    -video_size ${CAPTURE_W}x${CAPTURE_H} \
    -framerate 30 \
    -i :95.0+${OFFSET_X},${OFFSET_Y} \
    \
    `# AUDIO INPUT: Synthetic stereo audio` \
    -f lavfi \
    -i "anullsrc=channel_layout=stereo:sample_rate=44100" \
    \
    `# VIDEO FILTER: 2x upscale, center in HD frame` \
    -vf "scale=640:480:flags=neighbor,scale=1280:720:flags=lanczos:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2:black,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:text='🔴 LIVE ZX SPECTRUM OFFSET %{localtime}':fontcolor=yellow:fontsize=36:x=w-text_w-20:y=20:box=1:boxcolor=black@0.7:boxborderw=3" \
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
echo "✅ Offset-centered streaming completed!"
echo ""
echo "🎯 Offset Details:"
echo "   📐 Virtual Display: 800x600"
echo "   🔍 Capture Area: ${CAPTURE_W}x${CAPTURE_H} at +${OFFSET_X},${OFFSET_Y}"
echo "   📈 Scaling: 2x nearest neighbor (320x240 → 640x480)"
echo "   📺 Final: Centered in 1280x720 HD frame"
echo ""
echo "💡 If FUSE window is not centered, try adjusting:"
echo "   OFFSET_X and OFFSET_Y values in the script"
