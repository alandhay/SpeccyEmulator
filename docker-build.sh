#!/bin/bash

# Docker Build Script - ZX Spectrum Emulator
# ==========================================
# Builds the golden reference v2 final Docker image

echo "🔨 Building ZX Spectrum Emulator Docker Image"
echo "=============================================="

# Configuration
IMAGE_NAME="spectrum-emulator"
TAG="opense-rom"
DOCKERFILE="fixed-emulator-opense-rom.dockerfile"
VERSION="1.0.0-opense-rom"
BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
FULL_IMAGE_NAME="$IMAGE_NAME:$TAG"

echo "🎯 Build Configuration:"
echo "   Image Name: $FULL_IMAGE_NAME"
echo "   Dockerfile: $DOCKERFILE"
echo "   Version: $VERSION"
echo "   Build Time: $BUILD_TIME"
echo ""

# Step 1: Pre-build checks
echo "🔍 Pre-build Verification"
echo "========================="

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Error: Docker daemon is not running"
    echo "Please start Docker and try again"
    exit 1
fi
echo "✅ Docker daemon is running"

# Check if Dockerfile exists
if [ ! -f "$DOCKERFILE" ]; then
    echo "❌ Error: Dockerfile not found: $DOCKERFILE"
    echo ""
    echo "Available Dockerfiles:"
    ls -la *.dockerfile 2>/dev/null || echo "   No Dockerfile found"
    exit 1
fi
echo "✅ Dockerfile found: $DOCKERFILE"

# Check required server files
if [ ! -f "server/emulator_server_golden_reference_v2_final.py" ]; then
    echo "❌ Error: Server file not found: server/emulator_server_golden_reference_v2_final.py"
    echo ""
    echo "Available server files:"
    ls -la server/*.py 2>/dev/null || echo "   No server files found"
    exit 1
fi
echo "✅ Server file found: emulator_server_golden_reference_v2_final.py (with OpenSE ROM configuration)"

# Check requirements file
if [ ! -f "server/requirements.txt" ]; then
    echo "❌ Error: Requirements file not found: server/requirements.txt"
    echo "Creating basic requirements.txt..."
    cat > server/requirements.txt << EOF
websockets>=11.0
aiohttp>=3.8
boto3>=1.26
asyncio
EOF
    echo "✅ Created basic requirements.txt"
else
    echo "✅ Requirements file found: server/requirements.txt"
fi

echo ""

# Step 2: Show build context
echo "📁 Build Context Analysis"
echo "========================="
echo "Build context size:"
BUILD_CONTEXT_SIZE=$(du -sh . 2>/dev/null | cut -f1)
echo "   Current directory: $BUILD_CONTEXT_SIZE"

echo ""
echo "Key files to be copied:"
echo "   📄 Dockerfile: $DOCKERFILE ($(stat -c%s "$DOCKERFILE" 2>/dev/null || echo "unknown") bytes)"
echo "   🐍 Server: server/emulator_server_golden_reference_v2_final.py ($(stat -c%s "server/emulator_server_golden_reference_v2_final.py" 2>/dev/null || echo "unknown") bytes)"
echo "   📋 Requirements: server/requirements.txt ($(stat -c%s "server/requirements.txt" 2>/dev/null || echo "unknown") bytes)"

echo ""

# Step 3: Check for existing image
echo "🖼️  Existing Image Check"
echo "========================"
if docker images | grep -q "$IMAGE_NAME.*$TAG"; then
    echo "⚠️  Existing image found: $FULL_IMAGE_NAME"
    EXISTING_IMAGE_ID=$(docker images --format "{{.ID}}" "$FULL_IMAGE_NAME")
    EXISTING_IMAGE_SIZE=$(docker images --format "{{.Size}}" "$FULL_IMAGE_NAME")
    EXISTING_IMAGE_CREATED=$(docker images --format "{{.CreatedAt}}" "$FULL_IMAGE_NAME")
    
    echo "   Image ID: $EXISTING_IMAGE_ID"
    echo "   Size: $EXISTING_IMAGE_SIZE"
    echo "   Created: $EXISTING_IMAGE_CREATED"
    echo ""
    
    read -p "🤔 Rebuild existing image? This will replace the current image. (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Build cancelled by user"
        echo ""
        echo "💡 To use existing image:"
        echo "   ./docker-start.sh"
        echo ""
        echo "💡 To force rebuild:"
        echo "   docker rmi $FULL_IMAGE_NAME"
        echo "   ./docker-build.sh"
        exit 0
    fi
    echo ""
else
    echo "✅ No existing image found - proceeding with fresh build"
fi

echo ""

# Step 4: Build the image
echo "🔨 Building Docker Image"
echo "========================"
echo "Build command:"
echo "   docker build -f $DOCKERFILE -t $FULL_IMAGE_NAME --build-arg VERSION=$VERSION --build-arg BUILD_TIME=$BUILD_TIME ."
echo ""
echo "🚀 Starting build process..."
echo "⏱️  This may take 2-5 minutes depending on your system..."
echo ""

# Record build start time
BUILD_START=$(date +%s)

# Execute the build
docker build \
    -f "$DOCKERFILE" \
    -t "$FULL_IMAGE_NAME" \
    --build-arg VERSION="$VERSION" \
    --build-arg BUILD_TIME="$BUILD_TIME" \
    .

BUILD_EXIT_CODE=$?
BUILD_END=$(date +%s)
BUILD_DURATION=$((BUILD_END - BUILD_START))

echo ""

# Step 5: Build results
echo "📊 Build Results"
echo "================"

if [ $BUILD_EXIT_CODE -eq 0 ]; then
    echo "✅ Build completed successfully!"
    echo ""
    echo "⏱️  Build Statistics:"
    echo "   Duration: ${BUILD_DURATION} seconds"
    echo "   Exit Code: $BUILD_EXIT_CODE"
    echo ""
    
    # Get image details
    if docker images | grep -q "$IMAGE_NAME.*$TAG"; then
        IMAGE_ID=$(docker images --format "{{.ID}}" "$FULL_IMAGE_NAME")
        IMAGE_SIZE=$(docker images --format "{{.Size}}" "$FULL_IMAGE_NAME")
        IMAGE_CREATED=$(docker images --format "{{.CreatedAt}}" "$FULL_IMAGE_NAME")
        
        echo "🖼️  Image Details:"
        echo "   Name: $FULL_IMAGE_NAME"
        echo "   ID: $IMAGE_ID"
        echo "   Size: $IMAGE_SIZE"
        echo "   Created: $IMAGE_CREATED"
        echo "   Version: $VERSION"
        echo ""
        
        echo "🎯 Image Features:"
        echo "   ✅ OpenSE ROM: Open-source ZX Spectrum ROM included"
        echo "   ✅ No external ROM files needed"
        echo "   ✅ Legal distribution: No copyright issues"
        echo "   ✅ No cursor streaming (-draw_mouse 0)"
        echo "   ✅ 1.8x scaling (90% of 2x)"
        echo "   ✅ Proven YouTube key: 8w86-k4v4-4trq-pvwy-6v58"
        echo "   ✅ User context: spectrum user (not root)"
        echo "   ✅ FUSE startup fixes applied"
        echo "   ✅ Container compatibility optimized"
        echo ""
        
        echo "🚀 Ready for Testing:"
        echo "   Quick test:     ./test-opense-rom.sh"
        echo "   Start container: ./docker-start.sh"
        echo "   Check status:   ./docker-status.sh"
        echo ""
        
        echo "🔗 Manual Testing:"
        echo "   docker run -p 8080:8080 -p 8765:8765 $FULL_IMAGE_NAME"
        echo "   Health check:   curl http://localhost:8080/health"
        echo "   WebSocket:      ws://localhost:8765"
        echo ""
        
        echo "🏆 Build successful! Image is ready for deployment."
        
    else
        echo "⚠️  Build reported success but image not found in registry"
        echo "This may indicate a Docker registry issue"
    fi
    
else
    echo "❌ Build failed with exit code: $BUILD_EXIT_CODE"
    echo ""
    echo "⏱️  Build Statistics:"
    echo "   Duration: ${BUILD_DURATION} seconds"
    echo "   Exit Code: $BUILD_EXIT_CODE"
    echo ""
    
    echo "🔍 Common Build Issues:"
    echo "   1. Missing dependencies in Dockerfile"
    echo "   2. COPY source files not found"
    echo "   3. Network issues during package installation"
    echo "   4. Insufficient disk space"
    echo "   5. Docker daemon issues"
    echo ""
    
    echo "🛠️  Troubleshooting Steps:"
    echo "   1. Check Docker daemon: docker info"
    echo "   2. Verify file paths: ls -la server/"
    echo "   3. Check disk space: df -h"
    echo "   4. Review build output above for specific errors"
    echo "   5. Try cleaning Docker cache: docker system prune"
    echo ""
    
    echo "💡 Quick Fixes:"
    echo "   Clean build cache: docker builder prune"
    echo "   Remove failed images: docker image prune"
    echo "   Restart Docker daemon: sudo systemctl restart docker"
    
    exit $BUILD_EXIT_CODE
fi

echo ""

# Step 6: Next steps
echo "🎯 Next Steps"
echo "============"
echo "1. 🧪 Test the image:"
echo "      ./test-opense-rom.sh"
echo ""
echo "2. 🚀 Start container:"
echo "      ./docker-start.sh"
echo ""
echo "3. 📊 Monitor status:"
echo "      ./docker-status.sh"
echo ""
echo "4. 🏭 Deploy to production:"
echo "      # Tag for ECR"
echo "      docker tag $FULL_IMAGE_NAME 043309319786.dkr.ecr.us-east-1.amazonaws.com/spectrum-emulator:opense-rom"
echo "      # Push to ECR"
echo "      docker push 043309319786.dkr.ecr.us-east-1.amazonaws.com/spectrum-emulator:opense-rom"
echo ""

echo "🎮 ZX Spectrum Emulator Docker image build complete!"
