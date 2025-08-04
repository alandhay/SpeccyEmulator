#!/bin/bash

# ADJUSTABLE SOLUTION: Customizable Scaling + No Cursor + Perfect Centering
# =========================================================================
# This version allows you to easily adjust the scaling percentage while
# keeping the cursor hidden and everything perfectly centered.
#
# USAGE: ./stream_minimal_adjustable_scale.sh [SCALE_PERCENT]
# Example: ./stream_minimal_adjustable_scale.sh 85    # For 85% of 2x = 1.7x
# Default: 90% of 2x = 1.8x scaling

# Get scaling percentage from command line argument, default to 90%
SCALE_PERCENT=${1:-90}
SCALE_FACTOR=$(echo "scale=2; 2 * $SCALE_PERCENT / 100" | bc -l)

echo "🎮 ADJUSTABLE: ${SCALE_PERCENT}% Scaling + No Cursor + Perfect Center"
echo "=================================================================="

# YouTube streaming configuration
STREAM_KEY="3gpw-mdh2-6vwy-txb8-ebam"
RTMP_URL="rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY"

echo "Stream Key: $STREAM_KEY"
echo "RTMP URL: $RTMP_URL"
echo "Scaling: ${SCALE_PERCENT}% of 2x = ${SCALE_FACTOR}x total"
echo "Cursor: Hidden"
echo ""

# Install bc if not available (for floating point math)
if ! command -v bc &> /dev/null; then
    echo "Installing bc for scaling calculations..."
    sudo apt-get update -qq && sudo apt-get install -y bc
fi

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

# STEP 3: Calculate center capture area
DISPLAY_W=800
DISPLAY_H=600
CAPTURE_W=320  # Estimated FUSE window width
CAPTURE_H=240  # Estimated FUSE window height

# Calculate offset to center the capture
OFFSET_X=$(( (DISPLAY_W - CAPTURE_W) / 2 ))
OFFSET_Y=$(( (DISPLAY_H - CAPTURE_H) / 2 ))

echo "🎯 Stream settings:"
echo "   Display: ${DISPLAY_W}x${DISPLAY_H}"
echo "   Capture: ${CAPTURE_W}x${CAPTURE_H} at +${OFFSET_X},${OFFSET_Y}"
echo "   Scaling: ${SCALE_FACTOR}x (${SCALE_PERCENT}% of 2x)"
echo "   Cursor: Hidden with -draw_mouse 0"

# STEP 4: Stream with adjustable scaling and no cursor
echo "Starting adjustable scaled stream..."
echo "📺 Check YouTube Studio: https://studio.youtube.com"
echo "🛑 Press Ctrl+C to stop streaming"
echo ""
echo "💡 To change scaling next time:"
echo "   ./stream_minimal_adjustable_scale.sh 85   # For 85% = 1.7x"
echo "   ./stream_minimal_adjustable_scale.sh 95   # For 95% = 1.9x"
echo "   ./stream_minimal_adjustable_scale.sh 100  # For 100% = 2.0x"
echo ""

# ADJUSTABLE SCALING APPROACH:
# 1. Capture center area with NO CURSOR
# 2. Apply custom scaling factor
# 3. Center in HD frame with proper aspect ratio
# 4. Add timestamp overlay with scaling info
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
    `# VIDEO FILTER: Custom scaling, center in HD frame` \
    -vf "scale=iw*${SCALE_FACTOR}:ih*${SCALE_FACTOR}:flags=neighbor,scale=1280:720:flags=lanczos:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2:black,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:text='🔴 LIVE ZX SPECTRUM ${SCALE_FACTOR}X %{localtime}':fontcolor=yellow:fontsize=36:x=w-text_w-20:y=20:box=1:boxcolor=black@0.7:boxborderw=3" \
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
echo "✅ Adjustable scaling streaming completed!"
echo ""
echo "🎯 Final Settings Used:"
echo "   📐 Virtual Display: 800x600"
echo "   🔍 Capture Area: ${CAPTURE_W}x${CAPTURE_H} at +${OFFSET_X},${OFFSET_Y}"
echo "   🖱️  Mouse Cursor: Hidden"
echo "   📈 Scaling: ${SCALE_FACTOR}x (${SCALE_PERCENT}% of 2x)"
echo "   📺 Final: Centered in 1280x720 HD frame"
echo ""
echo "🔧 Scaling Options for Next Time:"
echo "   85% = 1.7x scaling (smaller)"
echo "   90% = 1.8x scaling (current default)"
echo "   95% = 1.9x scaling (slightly larger)"
echo "   100% = 2.0x scaling (full 2x)"
