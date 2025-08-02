#!/bin/bash

echo "Building HIGH BITRATE ZX Spectrum streaming Docker image..."

# Build the Docker image
docker build -f Dockerfile.high-bitrate -t spectrum-emulator:high-bitrate .

if [ $? -eq 0 ]; then
    echo "Docker image built successfully!"
    
    # Tag for ECR
    docker tag spectrum-emulator:high-bitrate \
        043309319786.dkr.ecr.us-east-1.amazonaws.com/spectrum-emulator:high-bitrate
    
    echo "Image tagged for ECR"
    
    # Login to ECR
    echo "Logging in to ECR..."
    aws ecr get-login-password --region us-east-1 | \
        docker login --username AWS --password-stdin \
        043309319786.dkr.ecr.us-east-1.amazonaws.com
    
    # Push to ECR
    echo "Pushing HIGH BITRATE image to ECR..."
    docker push 043309319786.dkr.ecr.us-east-1.amazonaws.com/spectrum-emulator:high-bitrate
    
    if [ $? -eq 0 ]; then
        echo "✅ HIGH BITRATE image pushed successfully!"
        echo ""
        echo "Image: 043309319786.dkr.ecr.us-east-1.amazonaws.com/spectrum-emulator:high-bitrate"
        echo ""
        echo "Next steps:"
        echo "1. Run: ./create-high-bitrate-task.sh"
        echo "2. This will deploy the high bitrate streaming configuration"
        echo "3. YouTube stream should have much better quality at 1080p with 6Mbps bitrate"
    else
        echo "❌ Failed to push image to ECR"
        exit 1
    fi
else
    echo "❌ Failed to build Docker image"
    exit 1
fi
