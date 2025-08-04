#!/bin/bash

# Complete Deployment Script for ZX Spectrum Emulator with OpenSE ROM
# ===================================================================
# Builds, tests, and optionally deploys the OpenSE ROM version

echo "🚀 ZX Spectrum Emulator - OpenSE ROM Deployment"
echo "==============================================="
echo "This script will build, test, and deploy the emulator with OpenSE ROM"
echo ""

# Configuration
IMAGE_NAME="spectrum-emulator"
TAG="opense-rom"
FULL_IMAGE_NAME="$IMAGE_NAME:$TAG"
ECR_REGISTRY="043309319786.dkr.ecr.us-east-1.amazonaws.com"
ECR_IMAGE="$ECR_REGISTRY/$IMAGE_NAME:$TAG"

# Step 1: Pre-deployment checks
echo "🔍 Pre-deployment Checks"
echo "========================"

# Check Docker
if ! docker info >/dev/null 2>&1; then
    echo "❌ Error: Docker daemon is not running"
    exit 1
fi
echo "✅ Docker daemon is running"

# Check required files
if [ ! -f "fixed-emulator-opense-rom.dockerfile" ]; then
    echo "❌ Error: OpenSE ROM Dockerfile not found"
    exit 1
fi
echo "✅ OpenSE ROM Dockerfile found"

if [ ! -f "server/emulator_server_golden_reference_v2_final.py" ]; then
    echo "❌ Error: Server file with OpenSE ROM configuration not found"
    exit 1
fi
echo "✅ Server file with OpenSE ROM configuration found"

echo ""

# Step 2: Build the image
echo "🔨 Building OpenSE ROM Image"
echo "============================"
echo "Building: $FULL_IMAGE_NAME"
echo ""

if ./build-opense-rom.sh; then
    echo "✅ Build completed successfully"
else
    echo "❌ Build failed"
    exit 1
fi

echo ""

# Step 3: Test the image
echo "🧪 Testing OpenSE ROM Image"
echo "==========================="
echo "Running comprehensive tests..."
echo ""

if ./test-opense-rom.sh; then
    echo "✅ Tests passed"
else
    echo "❌ Tests failed"
    read -p "Continue with deployment despite test failures? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Deployment aborted"
        exit 1
    fi
fi

echo ""

# Step 4: Tag for ECR
echo "🏷️  Tagging for ECR"
echo "=================="
echo "Tagging: $ECR_IMAGE"

if docker tag "$FULL_IMAGE_NAME" "$ECR_IMAGE"; then
    echo "✅ Tagged successfully"
else
    echo "❌ Tagging failed"
    exit 1
fi

echo ""

# Step 5: Ask about ECR push
echo "📤 ECR Deployment Options"
echo "========================"
echo "Image is ready for deployment to ECR"
echo ""
echo "Options:"
echo "1. Push to ECR now"
echo "2. Skip ECR push (local testing only)"
echo "3. Show push commands for manual execution"
echo ""

read -p "Choose option (1/2/3) [default: 2]: " -n 1 -r
echo

case $REPLY in
    1|Y|y)
        echo ""
        echo "📤 Pushing to ECR..."
        
        # Login to ECR
        echo "Logging in to ECR..."
        if aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin "$ECR_REGISTRY"; then
            echo "✅ ECR login successful"
        else
            echo "❌ ECR login failed"
            exit 1
        fi
        
        # Push image
        echo "Pushing image..."
        if docker push "$ECR_IMAGE"; then
            echo "✅ Image pushed successfully"
            echo ""
            echo "🎯 ECR Image Details:"
            echo "   Repository: $ECR_REGISTRY/$IMAGE_NAME"
            echo "   Tag: $TAG"
            echo "   Full URI: $ECR_IMAGE"
        else
            echo "❌ Image push failed"
            exit 1
        fi
        ;;
    3)
        echo ""
        echo "📋 Manual ECR Push Commands:"
        echo "============================"
        echo "# Login to ECR"
        echo "aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REGISTRY"
        echo ""
        echo "# Push image"
        echo "docker push $ECR_IMAGE"
        echo ""
        echo "# Verify push"
        echo "aws ecr describe-images --repository-name $IMAGE_NAME --region us-east-1"
        ;;
    *)
        echo ""
        echo "✅ Skipping ECR push - image available locally only"
        ;;
esac

echo ""

# Step 6: Deployment summary
echo "📊 Deployment Summary"
echo "===================="
echo "✅ Image built: $FULL_IMAGE_NAME"
echo "✅ Tests completed"
echo "✅ ECR tagged: $ECR_IMAGE"

if [[ $REPLY =~ ^[1Yy]$ ]]; then
    echo "✅ Pushed to ECR"
    echo ""
    echo "🏭 Production Deployment:"
    echo "   Update ECS task definition to use: $ECR_IMAGE"
    echo "   Deploy to ECS service"
else
    echo "⏳ Ready for ECR push"
fi

echo ""
echo "🎮 OpenSE ROM Features:"
echo "   ✅ Open source ZX Spectrum ROM"
echo "   ✅ No external ROM files needed"
echo "   ✅ Legal distribution"
echo "   ✅ Compatible with most ZX Spectrum software"
echo "   ✅ No copyright issues"
echo ""

echo "🎯 Next Steps:"
echo "   Local testing: ./docker-start.sh"
echo "   Check status:  ./docker-status.sh"
echo "   View logs:     docker logs -f spectrum-emulator-opense-test"
echo ""

echo "🏆 OpenSE ROM deployment completed successfully!"
echo "The emulator is ready with the open-source ROM configuration."
