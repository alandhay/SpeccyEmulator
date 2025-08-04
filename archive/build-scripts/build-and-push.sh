#!/bin/bash

set -e

# Configuration
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="043309319786"
REPOSITORY_NAME="spectrum-emulator"
IMAGE_TAG="latest"

echo "🚀 Building and pushing ZX Spectrum Emulator Docker image..."

# Get the full repository URI
REPOSITORY_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPOSITORY_NAME}"

echo "📦 Repository URI: ${REPOSITORY_URI}"

# Create ECR repository if it doesn't exist
echo "🔍 Checking if ECR repository exists..."
if ! aws ecr describe-repositories --repository-names ${REPOSITORY_NAME} --region ${AWS_REGION} >/dev/null 2>&1; then
    echo "📝 Creating ECR repository: ${REPOSITORY_NAME}"
    aws ecr create-repository \
        --repository-name ${REPOSITORY_NAME} \
        --region ${AWS_REGION} \
        --image-scanning-configuration scanOnPush=true
else
    echo "✅ ECR repository already exists"
fi

# Get login token and login to ECR
echo "🔐 Logging in to ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${REPOSITORY_URI}

# Build the Docker image
echo "🔨 Building Docker image..."
docker build -t ${REPOSITORY_NAME}:${IMAGE_TAG} .

# Tag the image for ECR
echo "🏷️  Tagging image for ECR..."
docker tag ${REPOSITORY_NAME}:${IMAGE_TAG} ${REPOSITORY_URI}:${IMAGE_TAG}

# Push the image to ECR
echo "⬆️  Pushing image to ECR..."
docker push ${REPOSITORY_URI}:${IMAGE_TAG}

echo "✅ Successfully built and pushed image: ${REPOSITORY_URI}:${IMAGE_TAG}"
echo ""
echo "🎯 Next steps:"
echo "1. Update ECS task definition to use: ${REPOSITORY_URI}:${IMAGE_TAG}"
echo "2. Deploy the updated task definition"
echo "3. Test the emulator with centered video capture"
