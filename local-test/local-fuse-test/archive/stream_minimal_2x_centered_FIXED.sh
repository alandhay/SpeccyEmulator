#!/bin/bash

# CENTERED SOLUTION: Properly Centered FUSE → YouTube Streaming
# =============================================================
# This version centers the FUSE window capture and applies proper scaling
# to show the complete ZX Spectrum display centered in the stream.
#
# CENTERED CAPTURE APPROACH:
# - Use larger virtual display to accommodate FUSE window positioning
# - Calculate center position for FUSE window
# - Capture specific area around the FUSE window
# - Apply 2x scaling to the captured FUSE area only
# - Center the result in the HD frame

echo "🎮 CENTERED: Properly Centered FUSE → YouTube Stream"
echo "===================================================="

# YouTube streaming configuration
STREAM_KEY="3gpw-mdh2-6vwy-txb8-ebam"
RTMP_URL="rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY"

echo "Stream Key: $STREAM_KEY"
echo "RTMP URL: $RTMP_URL"
echo "Approach: Centered capture with proper scaling"
echo ""

# STEP 1: Start virtual X11 display with room for centering
echo "Starting virtual display with centering space..."
export DISPLAY=:95

# Use larger display to give FUSE room to position itself
Xvfb :95 -screen 0 640x480x24 -ac &
sleep 3

echo "✅ Virtual display :95 started (640x480x24)"

# STEP 2: Start FUSE emulator
echo "Starting FUSE..."
fuse-sdl --machine 48 --no-sound &
sleep 5

echo "✅ FUSE ZX Spectrum 48K started"

# Wait a bit more for FUSE to fully initialize
sleep 2

# STEP 3: Find FUSE window position (if xwininfo is available)
if command -v xwininfo &> /dev/null; then
    echo "🔍 Detecting FUSE window position..."
    
    # Try to find FUSE window
    FUSE_WINDOW=$(xwininfo -root -tree -display :95 2>/dev/null | grep -i fuse | head -1 | awk '{print $1}' | sed 's/://g')
    
    if [ -n "$FUSE_WINDOW" ]; then
        WINDOW_INFO=$(xwininfo -id $FUSE_WINDOW -display :95 2>/dev/null)
        WINDOW_X=$(echo "$WINDOW_INFO" | grep "Absolute upper-left X:" | awk '{print $4}')
        WINDOW_Y=$(echo "$WINDOW_INFO" | grep "Absolute upper-left Y:" | awk '{print $4}')
        WINDOW_W=$(echo "$WINDOW_INFO" | grep "Width:" | awk '{print $2}')
        WINDOW_H=$(echo "$WINDOW_INFO" | grep "Height:" | awk '{print $2}')
        
        echo "📍 FUSE window found at: ${WINDOW_X},${WINDOW_Y} size: ${WINDOW_W}x${WINDOW_H}"
        
        # Use detected position
        CAPTURE_X=$WINDOW_X
        CAPTURE_Y=$WINDOW_Y
        CAPTURE_W=$WINDOW_W
        CAPTURE_H=$WINDOW_H
    else
        echo "⚠️  Could not detect FUSE window, using estimated position"
        # Fallback to estimated position
        CAPTURE_X=0
        CAPTURE_Y=0
        CAPTURE_W=320
        CAPTURE_H=240
    fi
else
    echo "⚠️  xwininfo not available, using estimated FUSE position"
    # Estimated FUSE window position and size
    CAPTURE_X=0
    CAPTURE_Y=0
    CAPTURE_W=320
    CAPTURE_H=240
fi

echo "🎯 Capture area: ${CAPTURE_W}x${CAPTURE_H} at offset +${CAPTURE_X},${CAPTURE_Y}"

# STEP 4: Stream with centered capture
echo "Starting centered capture stream..."
echo "📺 Check YouTube Studio: https://studio.youtube.com"
echo "🛑 Press Ctrl+C to stop streaming"
echo ""

# CENTERED CAPTURE APPROACH:
# 1. Capture specific area where FUSE window is located
# 2. Apply 2x nearest neighbor scaling
# 3. Center the result in HD frame with proper aspect ratio
# 4. Add timestamp overlay
ffmpeg \
    `# VIDEO INPUT: Capture FUSE window area specifically` \
    -f x11grab \
    -video_size ${CAPTURE_W}x${CAPTURE_H} \
    -framerate 30 \
    -i :95.0+${CAPTURE_X},${CAPTURE_Y} \
    \
    `# AUDIO INPUT: Synthetic stereo audio` \
    -f lavfi \
    -i "anullsrc=channel_layout=stereo:sample_rate=44100" \
    \
    `# VIDEO FILTER: 2x upscale, center in HD frame with aspect ratio` \
    -vf "scale=iw*2:ih*2:flags=neighbor,scale=1280:720:flags=lanczos:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2:black,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:text='🔴 LIVE ZX SPECTRUM CENTERED %{localtime}':fontcolor=yellow:fontsize=36:x=w-text_w-20:y=20:box=1:boxcolor=black@0.7:boxborderw=3" \
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
echo "✅ Centered streaming completed!"
echo ""
echo "🎯 Centering Details:"
echo "   📐 Virtual Display: 640x480 (room for positioning)"
echo "   🔍 Capture Area: ${CAPTURE_W}x${CAPTURE_H} at +${CAPTURE_X},${CAPTURE_Y}"
echo "   📈 Scaling: 2x nearest neighbor upscale"
echo "   📺 Final: Centered in 1280x720 HD frame"
