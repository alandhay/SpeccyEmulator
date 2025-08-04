#!/bin/bash

# FIXED SOLUTION: Proper 2x Upscaled FUSE → YouTube Streaming
# ===========================================================
# This version uses the correct ZX Spectrum native resolution and proper scaling
# to match the actual FUSE window size, not the entire virtual display.
#
# PROPER SCALING APPROACH:
# - Use virtual display that matches ZX Spectrum proportions
# - Capture at native 256x192 resolution (or scaled multiple)
# - Apply 2x nearest neighbor scaling (256x192 → 512x384)
# - Scale to fit HD frame while maintaining aspect ratio
# - This ensures the FUSE window fills the stream properly

echo "🎮 FIXED: Proper 2x Upscaled FUSE → YouTube Stream"
echo "================================================="

# YouTube streaming configuration
STREAM_KEY="3gpw-mdh2-6vwy-txb8-ebam"
RTMP_URL="rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY"

echo "Stream Key: $STREAM_KEY"
echo "RTMP URL: $RTMP_URL"
echo "Resolution: Native ZX Spectrum 256x192 → 2x scaled → HD fit"
echo ""

# STEP 1: Start virtual X11 display with proper ZX Spectrum proportions
echo "Starting virtual display with ZX Spectrum proportions..."
export DISPLAY=:95

# Use 512x384 (2x native 256x192) for better scaling
Xvfb :95 -screen 0 512x384x24 -ac &
sleep 3

echo "✅ Virtual display :95 started (512x384x24 - 2x ZX Spectrum native)"

# STEP 2: Start FUSE emulator
echo "Starting FUSE..."
fuse-sdl --machine 48 --no-sound &
sleep 5

echo "✅ FUSE ZX Spectrum 48K started"

# STEP 3: Stream with proper 2x upscaling
echo "Starting properly scaled stream..."
echo "📺 Check YouTube Studio: https://studio.youtube.com"
echo "🛑 Press Ctrl+C to stop streaming"
echo ""

# PROPER 2X UPSCALING APPROACH:
# 1. Capture at 512x384 (2x native ZX Spectrum)
# 2. Apply additional 2x scaling for total 4x (512x384 → 1024x768)
# 3. Scale to fit 1280x720 HD frame with proper aspect ratio
# 4. Add timestamp overlay
ffmpeg \
    `# VIDEO INPUT: Capture virtual display at 2x native resolution` \
    -f x11grab \
    -video_size 512x384 \
    -framerate 30 \
    -i :95.0+0,0 \
    \
    `# AUDIO INPUT: Synthetic stereo audio` \
    -f lavfi \
    -i "anullsrc=channel_layout=stereo:sample_rate=44100" \
    \
    `# VIDEO FILTER: Additional 2x upscale, then fit to HD with aspect ratio` \
    -vf "scale=1024:768:flags=neighbor,scale=1280:720:flags=lanczos:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2:black,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:text='🔴 LIVE ZX SPECTRUM 2X %{localtime}':fontcolor=yellow:fontsize=36:x=w-text_w-20:y=20:box=1:boxcolor=black@0.7:boxborderw=3" \
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
echo "✅ Properly scaled streaming completed!"
echo ""
echo "🎯 Scaling Details:"
echo "   📐 Virtual Display: 512x384 (2x ZX Spectrum native)"
echo "   🔍 FFmpeg Capture: 512x384"
echo "   📈 First Scale: 512x384 → 1024x768 (2x nearest neighbor)"
echo "   📺 Final Scale: 1024x768 → 1280x720 (fit with aspect ratio)"
echo "   🎮 Total Magnification: 4x from native 256x192"
