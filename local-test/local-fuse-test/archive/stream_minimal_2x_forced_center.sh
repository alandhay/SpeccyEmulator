#!/bin/bash

# ADVANCED SOLUTION: Force-Centered FUSE → YouTube Streaming
# ==========================================================
# This version uses window management to force FUSE to center itself
# in the virtual display, ensuring perfect centering in the stream.
#
# FORCE-CENTERING APPROACH:
# - Start FUSE in a controlled virtual display
# - Use xdotool to move FUSE window to center
# - Capture the centered area with proper scaling
# - Apply 2x scaling and center in HD frame

echo "🎮 ADVANCED: Force-Centered FUSE → YouTube Stream"
echo "================================================="

# YouTube streaming configuration
STREAM_KEY="3gpw-mdh2-6vwy-txb8-ebam"
RTMP_URL="rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY"

echo "Stream Key: $STREAM_KEY"
echo "RTMP URL: $RTMP_URL"
echo "Approach: Force window centering with xdotool"
echo ""

# Install xdotool if not available
if ! command -v xdotool &> /dev/null; then
    echo "Installing xdotool for window management..."
    sudo apt-get update -qq && sudo apt-get install -y xdotool
fi

# STEP 1: Start virtual X11 display optimized for centering
echo "Starting virtual display optimized for centering..."
export DISPLAY=:95

# Use display size that's a multiple of ZX Spectrum resolution for perfect centering
# 512x384 = 2x native ZX Spectrum (256x192)
Xvfb :95 -screen 0 512x384x24 -ac &
sleep 3

echo "✅ Virtual display :95 started (512x384x24 - 2x ZX Spectrum)"

# STEP 2: Start lightweight window manager for better window control
echo "Starting window manager..."
openbox --display :95 &
sleep 2

echo "✅ Window manager started"

# STEP 3: Start FUSE emulator
echo "Starting FUSE..."
fuse-sdl --machine 48 --no-sound &
sleep 5

echo "✅ FUSE ZX Spectrum 48K started"

# STEP 4: Force center the FUSE window
echo "🎯 Force-centering FUSE window..."

# Wait for FUSE window to appear
sleep 2

# Find and center FUSE window
FUSE_WINDOW=$(xdotool search --name "fuse" 2>/dev/null | head -1)

if [ -n "$FUSE_WINDOW" ]; then
    echo "📍 Found FUSE window: $FUSE_WINDOW"
    
    # Get window size
    eval $(xdotool getwindowgeometry --shell $FUSE_WINDOW)
    
    # Calculate center position
    DISPLAY_W=512
    DISPLAY_H=384
    CENTER_X=$(( (DISPLAY_W - WIDTH) / 2 ))
    CENTER_Y=$(( (DISPLAY_H - HEIGHT) / 2 ))
    
    echo "📐 Centering window: ${WIDTH}x${HEIGHT} to position ${CENTER_X},${CENTER_Y}"
    
    # Move window to center
    xdotool windowmove $FUSE_WINDOW $CENTER_X $CENTER_Y
    
    echo "✅ FUSE window centered"
    
    # Use centered capture
    CAPTURE_X=$CENTER_X
    CAPTURE_Y=$CENTER_Y
    CAPTURE_W=$WIDTH
    CAPTURE_H=$HEIGHT
else
    echo "⚠️  Could not find FUSE window, using full display capture"
    # Fallback to full display
    CAPTURE_X=0
    CAPTURE_Y=0
    CAPTURE_W=512
    CAPTURE_H=384
fi

# STEP 5: Stream with perfectly centered capture
echo "Starting perfectly centered stream..."
echo "📺 Check YouTube Studio: https://studio.youtube.com"
echo "🛑 Press Ctrl+C to stop streaming"
echo ""

# FORCE-CENTERED APPROACH:
# 1. Capture the centered FUSE window area
# 2. Apply 2x nearest neighbor scaling
# 3. Center in HD frame with proper aspect ratio
# 4. Add timestamp overlay
ffmpeg \
    `# VIDEO INPUT: Capture centered FUSE area` \
    -f x11grab \
    -video_size ${CAPTURE_W}x${CAPTURE_H} \
    -framerate 30 \
    -i :95.0+${CAPTURE_X},${CAPTURE_Y} \
    \
    `# AUDIO INPUT: Synthetic stereo audio` \
    -f lavfi \
    -i "anullsrc=channel_layout=stereo:sample_rate=44100" \
    \
    `# VIDEO FILTER: 2x upscale, center in HD frame perfectly` \
    -vf "scale=iw*2:ih*2:flags=neighbor,scale=1280:720:flags=lanczos:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2:black,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:text='🔴 LIVE ZX SPECTRUM PERFECT CENTER %{localtime}':fontcolor=yellow:fontsize=36:x=w-text_w-20:y=20:box=1:boxcolor=black@0.7:boxborderw=3" \
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
echo "   pkill -f openbox   # Stop window manager"
echo "   pkill -f Xvfb      # Stop virtual display"
echo ""
echo "✅ Force-centered streaming completed!"
echo ""
echo "🎯 Perfect Centering Details:"
echo "   📐 Virtual Display: 512x384 (2x ZX Spectrum)"
echo "   🎯 Window Position: Calculated center"
echo "   🔍 Capture Area: ${CAPTURE_W}x${CAPTURE_H} at +${CAPTURE_X},${CAPTURE_Y}"
echo "   📈 Scaling: 2x nearest neighbor upscale"
echo "   📺 Final: Perfectly centered in 1280x720 HD frame"
