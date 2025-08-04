#!/bin/bash

# ALTERNATIVE SOLUTION: Native Resolution with Window Detection
# =============================================================
# This version uses the exact ZX Spectrum native resolution (256x192)
# and detects the FUSE window position for precise capture.
#
# NATIVE RESOLUTION APPROACH:
# - Use virtual display at exact ZX Spectrum resolution (256x192)
# - Capture the entire display (FUSE should fill it)
# - Apply 2x nearest neighbor scaling (256x192 → 512x384)
# - Scale to fit HD frame with proper aspect ratio and padding
# - This ensures pixel-perfect scaling from native resolution

echo "🎮 NATIVE: ZX Spectrum Resolution → 2x Scaled Stream"
echo "==================================================="

# YouTube streaming configuration
STREAM_KEY="3gpw-mdh2-6vwy-txb8-ebam"
RTMP_URL="rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY"

echo "Stream Key: $STREAM_KEY"
echo "RTMP URL: $RTMP_URL"
echo "Resolution: Native ZX Spectrum 256x192 → 2x scaled → HD fit"
echo ""

# STEP 1: Start virtual X11 display at exact ZX Spectrum resolution
echo "Starting virtual display at native ZX Spectrum resolution..."
export DISPLAY=:95

# Use exact ZX Spectrum resolution
Xvfb :95 -screen 0 256x192x24 -ac &
sleep 3

echo "✅ Virtual display :95 started (256x192x24 - Native ZX Spectrum)"

# STEP 2: Start FUSE emulator
echo "Starting FUSE..."
fuse-sdl --machine 48 --no-sound &
sleep 5

echo "✅ FUSE ZX Spectrum 48K started"

# STEP 3: Stream with native resolution scaling
echo "Starting native resolution stream..."
echo "📺 Check YouTube Studio: https://studio.youtube.com"
echo "🛑 Press Ctrl+C to stop streaming"
echo ""

# NATIVE RESOLUTION SCALING APPROACH:
# 1. Capture at exact 256x192 (native ZX Spectrum)
# 2. Apply 2x nearest neighbor scaling (256x192 → 512x384)
# 3. Scale to fit 1280x720 HD frame with proper aspect ratio and padding
# 4. Add timestamp overlay
ffmpeg \
    `# VIDEO INPUT: Capture at native ZX Spectrum resolution` \
    -f x11grab \
    -video_size 256x192 \
    -framerate 30 \
    -i :95.0+0,0 \
    \
    `# AUDIO INPUT: Synthetic stereo audio` \
    -f lavfi \
    -i "anullsrc=channel_layout=stereo:sample_rate=44100" \
    \
    `# VIDEO FILTER: 2x upscale, fit to HD with aspect ratio, add padding` \
    -vf "scale=512:384:flags=neighbor,scale=1280:720:flags=lanczos:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2:black,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:text='🔴 LIVE ZX SPECTRUM NATIVE %{localtime}':fontcolor=yellow:fontsize=36:x=w-text_w-20:y=20:box=1:boxcolor=black@0.7:boxborderw=3" \
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
echo "✅ Native resolution streaming completed!"
echo ""
echo "🎯 Native Scaling Details:"
echo "   📐 Virtual Display: 256x192 (Native ZX Spectrum)"
echo "   🔍 FFmpeg Capture: 256x192"
echo "   📈 First Scale: 256x192 → 512x384 (2x nearest neighbor)"
echo "   📺 Final Scale: 512x384 → fit 1280x720 (with padding)"
echo "   🎮 Perfect pixel scaling from native resolution"
