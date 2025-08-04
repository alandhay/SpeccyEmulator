#!/bin/bash

# Build Golden Reference v2 ZX Spectrum Emulator Docker Image
# ===========================================================
# This script builds the v2 golden reference Docker image that fixes
# critical user context issues causing FUSE to hang at splash screen.

echo "🏆 Building Golden Reference v2 ZX Spectrum Emulator Docker Image"
echo "================================================================="

# Configuration
IMAGE_NAME="spectrum-emulator"
TAG="golden-reference-v2"
DOCKERFILE="fixed-emulator-golden-reference-v2.dockerfile"
VERSION="1.0.0-golden-reference-v2"
BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "Image: $IMAGE_NAME:$TAG"
echo "Dockerfile: $DOCKERFILE"
echo "Version: $VERSION"
echo "Build Time: $BUILD_TIME"
echo ""
echo "🔧 Critical Fixes in v2:"
echo "   ✅ User Context: Run as 'spectrum' user (not root)"
echo "   ✅ Home Directory: Proper /home/spectrum setup"
echo "   ✅ FUSE Config: Created .fuse configuration directory"
echo "   ✅ SDL Environment: Explicit driver configuration"
echo "   ✅ Device Nodes: Created necessary /dev entries"
echo "   ✅ Startup Sequence: Enhanced FUSE initialization"
echo ""

# Verify required files exist
echo "🔍 Verifying required files..."

if [ ! -f "$DOCKERFILE" ]; then
    echo "❌ Error: Dockerfile not found: $DOCKERFILE"
    exit 1
fi

if [ ! -f "server/emulator_server_golden_reference_v2.py" ]; then
    echo "❌ Error: Golden reference v2 server not found: server/emulator_server_golden_reference_v2.py"
    exit 1
fi

if [ ! -f "server/requirements.txt" ]; then
    echo "❌ Error: Requirements file not found: server/requirements.txt"
    exit 1
fi

echo "✅ All required files found"
echo ""

# Build the Docker image
echo "🔨 Building Docker image with user context fixes..."
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
    echo "   Strategy: Golden Reference v2 (user context fixes)"
    echo "   Build Time: $BUILD_TIME"
    echo ""
    echo "🔧 Key Improvements:"
    echo "   ✅ Runs as 'spectrum' user instead of root"
    echo "   ✅ Proper home directory and FUSE config setup"
    echo "   ✅ Enhanced SDL environment configuration"
    echo "   ✅ Container-compatible device node creation"
    echo "   ✅ Longer FUSE startup wait time (10 seconds)"
    echo ""
    echo "📊 Image Information:"
    docker images | grep "$IMAGE_NAME" | grep "$TAG"
    echo ""
    echo "🚀 Ready for local testing:"
    echo "   docker run -p 8080:8080 -p 8765:8765 $IMAGE_NAME:$TAG"
    echo ""
    echo "🔧 Environment Variables (optional):"
    echo "   -e YOUTUBE_STREAM_KEY=your_key"
    echo "   -e SCALE_FACTOR=1.8"
    echo "   -e FRAME_RATE=30"
    echo ""
    echo "🏆 Golden Reference v2 Docker image is ready for testing!"
    echo ""
    echo "🎯 Expected Result:"
    echo "   FUSE should now start properly and reach the ZX Spectrum ready screen"
    echo "   (not stuck at splash screen like previous versions)"
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
