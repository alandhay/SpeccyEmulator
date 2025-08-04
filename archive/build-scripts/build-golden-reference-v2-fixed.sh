#!/bin/bash

# Build Golden Reference v2 FIXED ZX Spectrum Emulator Docker Image
# =================================================================
# This script builds the v2 FIXED golden reference Docker image that resolves
# both the FUSE startup issue AND the FFmpeg filter syntax issue.

echo "🏆 Building Golden Reference v2 FIXED ZX Spectrum Emulator Docker Image"
echo "========================================================================"

# Configuration
IMAGE_NAME="spectrum-emulator"
TAG="golden-reference-v2-fixed"
DOCKERFILE="fixed-emulator-golden-reference-v2-fixed.dockerfile"
VERSION="1.0.0-golden-reference-v2-fixed"
BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "Image: $IMAGE_NAME:$TAG"
echo "Dockerfile: $DOCKERFILE"
echo "Version: $VERSION"
echo "Build Time: $BUILD_TIME"
echo ""
echo "🔧 Critical Fixes in v2 FIXED:"
echo "   ✅ User Context: Run as 'spectrum' user (not root) - FUSE STARTUP FIXED"
echo "   ✅ Home Directory: Proper /home/spectrum setup"
echo "   ✅ FUSE Config: Created .fuse configuration directory"
echo "   ✅ SDL Environment: Explicit driver configuration"
echo "   ✅ Device Nodes: Created necessary /dev entries"
echo "   ✅ FFmpeg Filters: FIXED video filter chain syntax - STREAMING FIXED"
echo "   ✅ Startup Sequence: Enhanced FUSE initialization"
echo ""

# Verify required files exist
echo "🔍 Verifying required files..."

if [ ! -f "$DOCKERFILE" ]; then
    echo "❌ Error: Dockerfile not found: $DOCKERFILE"
    exit 1
fi

if [ ! -f "server/emulator_server_golden_reference_v2_fixed.py" ]; then
    echo "❌ Error: Golden reference v2 FIXED server not found: server/emulator_server_golden_reference_v2_fixed.py"
    exit 1
fi

if [ ! -f "server/requirements.txt" ]; then
    echo "❌ Error: Requirements file not found: server/requirements.txt"
    exit 1
fi

echo "✅ All required files found"
echo ""

# Build the Docker image
echo "🔨 Building Docker image with ALL fixes applied..."
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
    echo "   Strategy: Golden Reference v2 FIXED (user context + FFmpeg fixes)"
    echo "   Build Time: $BUILD_TIME"
    echo ""
    echo "🔧 ALL Key Fixes Applied:"
    echo "   ✅ FUSE Startup Issue: RESOLVED (runs as spectrum user)"
    echo "   ✅ FFmpeg Filter Issue: RESOLVED (fixed video filter syntax)"
    echo "   ✅ User Context: Proper home directory and config setup"
    echo "   ✅ SDL Environment: Enhanced configuration"
    echo "   ✅ Container Compatibility: Device nodes and permissions"
    echo ""
    echo "📊 Image Information:"
    docker images | grep "$IMAGE_NAME" | grep "$TAG"
    echo ""
    echo "🚀 Ready for local testing:"
    echo "   docker run -p 8082:8080 -p 8767:8765 $IMAGE_NAME:$TAG"
    echo ""
    echo "🔧 Environment Variables (optional):"
    echo "   -e YOUTUBE_STREAM_KEY=your_key"
    echo "   -e SCALE_FACTOR=1.8"
    echo "   -e FRAME_RATE=30"
    echo ""
    echo "🏆 Golden Reference v2 FIXED Docker image is ready for testing!"
    echo ""
    echo "🎯 Expected Results:"
    echo "   ✅ FUSE starts properly (no splash screen hang)"
    echo "   ✅ FFmpeg video streaming works (no filter errors)"
    echo "   ✅ Complete ZX Spectrum emulator streaming pipeline"
    echo "   ✅ Health checks pass for all components"
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
