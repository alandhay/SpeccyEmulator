#!/bin/bash

# Build script for ZX Spectrum Emulator with OpenSE ROM
# This ensures all future builds use the open-source ROM by default

set -e

echo "🏗️  Building ZX Spectrum Emulator with OpenSE ROM"
echo "================================================"

# Configuration
IMAGE_NAME="spectrum-emulator"
TAG="opense-rom"
DOCKERFILE="fixed-emulator-opense-rom.dockerfile"

# Build the Docker image
echo "📦 Building Docker image: ${IMAGE_NAME}:${TAG}"
docker build -f ${DOCKERFILE} -t ${IMAGE_NAME}:${TAG} .

# Tag for ECR if needed
ECR_REGISTRY="043309319786.dkr.ecr.us-east-1.amazonaws.com"
ECR_IMAGE="${ECR_REGISTRY}/${IMAGE_NAME}:${TAG}"

echo "🏷️  Tagging for ECR: ${ECR_IMAGE}"
docker tag ${IMAGE_NAME}:${TAG} ${ECR_IMAGE}

echo "✅ Build complete!"
echo ""
echo "🚀 To run locally:"
echo "   docker run -p 8080:8080 -p 8765:8765 ${IMAGE_NAME}:${TAG}"
echo ""
echo "📤 To push to ECR:"
echo "   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${ECR_REGISTRY}"
echo "   docker push ${ECR_IMAGE}"
echo ""
echo "🎮 This image will always use OpenSE ROM - no external ROM files needed!"
