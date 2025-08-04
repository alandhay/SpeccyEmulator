#!/bin/bash
# Deploy Proven Key Injection Fix

set -e

# Prevent interactive prompts
export DEBIAN_FRONTEND=noninteractive

echo "🚀 DEPLOYING PROVEN KEY INJECTION FIX"
echo "====================================="

# Build Docker image
echo "📦 Building Docker image with proven key injection method..."
docker build -f fixed-emulator-v6-keys.dockerfile -t spectrum-emulator:v6-proven-keys .

# Tag for ECR
echo "🏷️  Tagging for ECR..."
docker tag spectrum-emulator:v6-proven-keys \
  043309319786.dkr.ecr.us-east-1.amazonaws.com/spectrum-emulator:v6-proven-keys

# Login to ECR
echo "🔐 Logging into ECR..."
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  043309319786.dkr.ecr.us-east-1.amazonaws.com

# Push to ECR
echo "📤 Pushing to ECR..."
docker push 043309319786.dkr.ecr.us-east-1.amazonaws.com/spectrum-emulator:v6-proven-keys

echo ""
echo "✅ BUILD COMPLETE!"
echo "=================="
echo "Docker image built and pushed with proven key injection method"
echo ""
echo "🚀 TO DEPLOY:"
echo "1. Update your task definition to use: spectrum-emulator:v6-proven-keys"
echo "2. Deploy to development first"
echo "3. Test keys via web interface - they should appear on livestream immediately"
echo ""
echo "🎯 SUCCESS CRITERIA:"
echo "- Keys appear on livestream when pressed"
echo "- Health check shows 'key_injection_ready: true'"
echo "- No WebSocket error 1011"
