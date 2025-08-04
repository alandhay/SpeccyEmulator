#!/bin/bash

set -e

echo "🏗️  Building Golden Reference ZX Spectrum Emulator v2 FINAL (Environment Aware)"
echo "=============================================================================="

# Configuration
IMAGE_NAME="spectrum-emulator"
TAG="golden-reference-v2-final-env-aware"
FULL_IMAGE_NAME="${IMAGE_NAME}:${TAG}"

echo "📋 Build Configuration:"
echo "  Image Name: ${FULL_IMAGE_NAME}"
echo "  Dockerfile: fixed-emulator-golden-reference-v2-final-env-aware.dockerfile"
echo "  Context: Current directory"
echo ""

# Build the Docker image
echo "🔨 Building Docker image..."
docker build \
    -f fixed-emulator-golden-reference-v2-final-env-aware.dockerfile \
    -t "${FULL_IMAGE_NAME}" \
    .

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build completed successfully!"
    echo ""
    echo "📊 Image Information:"
    docker images "${FULL_IMAGE_NAME}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
    echo ""
    echo "🚀 Ready to run with:"
    echo "  Local Test:  docker run -p 8080:8080 -p 8765:8765 ${FULL_IMAGE_NAME}"
    echo "  With YouTube: docker run -p 8080:8080 -p 8765:8765 -e YOUTUBE_STREAM_KEY=your-key ${FULL_IMAGE_NAME}"
    echo ""
    echo "🌍 Environment Detection:"
    echo "  • S3 uploads will be DISABLED when running locally"
    echo "  • S3 uploads will be ENABLED when running on AWS/ECS"
    echo "  • YouTube streaming works in both environments"
    echo ""
    echo "🔍 Test the build:"
    echo "  docker run --rm ${FULL_IMAGE_NAME} python3 -c \"import requests; print('Environment detection ready')\""
else
    echo ""
    echo "❌ Build failed!"
    exit 1
fi
