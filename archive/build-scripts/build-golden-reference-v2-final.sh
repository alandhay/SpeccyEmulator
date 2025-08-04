#!/bin/bash

# Build Golden Reference v2 FINAL ZX Spectrum Emulator Docker Image
# =================================================================
# This script builds the FINAL golden reference Docker image that uses
# the EXACT proven local test configuration including:
# - No cursor (-draw_mouse 0)
# - 1.8x scaling (90% of 2x)
# - Proven YouTube stream key: 8w86-k4v4-4trq-pvwy-6v58

echo "🏆 Building Golden Reference v2 FINAL ZX Spectrum Emulator Docker Image"
echo "========================================================================"

# Configuration
IMAGE_NAME="spectrum-emulator"
TAG="golden-reference-v2-final"
DOCKERFILE="fixed-emulator-golden-reference-v2-final.dockerfile"
VERSION="1.0.0-golden-reference-v2-final"
BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "Image: $IMAGE_NAME:$TAG"
echo "Dockerfile: $DOCKERFILE"
echo "Version: $VERSION"
echo "Build Time: $BUILD_TIME"
echo ""
echo "🎯 FINAL Configuration (matching proven local test):"
echo "   ✅ Virtual Display: 800x600x24"
echo "   ✅ Capture Area: 320x240 at +240,+180"
echo "   ✅ Scaling: 1.8x (90% of 2x) - proven optimal"
echo "   ✅ No Cursor: -draw_mouse 0 applied"
echo "   ✅ YouTube Key: 8w86-k4v4-4trq-pvwy-6v58 (proven working)"
echo "   ✅ User Context: spectrum user (not root)"
echo "   ✅ FUSE Config: Proper home directory setup"
echo ""

# Verify required files exist
echo "🔍 Verifying required files..."

if [ ! -f "$DOCKERFILE" ]; then
    echo "❌ Error: Dockerfile not found: $DOCKERFILE"
    exit 1
fi

if [ ! -f "server/emulator_server_golden_reference_v2_final.py" ]; then
    echo "❌ Error: FINAL server not found: server/emulator_server_golden_reference_v2_final.py"
    exit 1
fi

if [ ! -f "server/requirements.txt" ]; then
    echo "❌ Error: Requirements file not found: server/requirements.txt"
    exit 1
fi

echo "✅ All required files found"
echo ""

# Build the Docker image
echo "🔨 Building Docker image with FINAL proven configuration..."
echo "Command: docker build -f $DOCKERFILE -t $IMAGE_NAME:$TAG ."
echo ""

docker build \
    -f "$DOCKERFILE" \
    -t "$IMAGE_NAME:$TAG" \
    --build-arg VERSION="$VERSION" \
    --build-arg BUILD_TIME="$BUILD_TIME" \
    .

BUILD_EXIT_CODE=$?

if [ $BUILD_EXIT_CODE -eq 0 ]; then
    echo ""
    echo "✅ Docker image built successfully!"
    echo ""
    echo "🎯 Image Details:"
    echo "   Name: $IMAGE_NAME:$TAG"
    echo "   Version: $VERSION"
    echo "   Strategy: FINAL - Exact match to proven local test"
    echo "   Build Time: $BUILD_TIME"
    echo ""
    echo "🏆 FINAL Features Applied:"
    echo "   ✅ No Cursor: Clean streams without mouse pointer"
    echo "   ✅ 1.8x Scaling: Perfect size (90% of 2x)"
    echo "   ✅ Proven YouTube Key: 8w86-k4v4-4trq-pvwy-6v58"
    echo "   ✅ User Context: Runs as spectrum user"
    echo "   ✅ FUSE Startup: No splash screen hang"
    echo "   ✅ Container Compatibility: All device nodes and permissions"
    echo ""
    echo "📊 Image Information:"
    docker images | grep "$IMAGE_NAME" | grep "$TAG"
    echo ""
    echo "🚀 Ready for local testing:"
    echo "   docker run -p 8082:8080 -p 8767:8765 $IMAGE_NAME:$TAG"
    echo ""
    echo "🔧 Environment Variables (optional overrides):"
    echo "   -e YOUTUBE_STREAM_KEY=your_key"
    echo "   -e SCALE_FACTOR=1.8"
    echo "   -e FRAME_RATE=30"
    echo ""
    echo "🏆 Golden Reference v2 FINAL Docker image is ready!"
    echo ""
    echo "🎯 Expected Results:"
    echo "   ✅ FUSE starts properly (no splash screen hang)"
    echo "   ✅ FFmpeg streaming works with no cursor"
    echo "   ✅ 1.8x scaling provides perfect video size"
    echo "   ✅ YouTube streaming works with proven key"
    echo "   ✅ Health checks pass for all components"
    echo ""
    echo "📺 YouTube Studio Check:"
    echo "   https://studio.youtube.com"
    echo "   Stream should appear with clean, cursor-free video"
    echo "   Resolution: 1280x720 with ZX Spectrum centered"
    echo "   Scaling: 1.8x (576x432 scaled from 320x240)"
else
    echo ""
    echo "❌ Docker build failed with exit code: $BUILD_EXIT_CODE"
    echo ""
    echo "🔍 Troubleshooting:"
    echo "   1. Check Dockerfile syntax"
    echo "   2. Verify all COPY sources exist"
    echo "   3. Check Docker daemon is running"
    echo "   4. Review build output above for specific errors"
    exit $BUILD_EXIT_CODE
fi
