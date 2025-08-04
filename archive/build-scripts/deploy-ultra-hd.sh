#!/bin/bash

echo "🚀 === ZX Spectrum ULTRA HD 1080p Deployment === 🚀"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}🎬 Deploying ULTRA HD 1080p @ 60fps @ 8Mbps streaming...${NC}"
echo ""

# Step 1: Create the task definition
echo -e "${YELLOW}📝 Step 1: Creating ULTRA HD task definition...${NC}"
./create-ultra-hd-streaming.sh

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to create task definition${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}🔄 Step 2: Updating ECS service...${NC}"

# Update the service to use the new task definition
aws ecs update-service \
    --cluster spectrum-emulator-cluster-dev \
    --service spectrum-youtube-streaming \
    --task-definition spectrum-emulator-streaming \
    --region us-east-1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Service update initiated successfully!${NC}"
else
    echo -e "${RED}❌ Failed to update service${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}⏳ Step 3: Waiting for deployment to complete...${NC}"

# Wait for the service to stabilize
echo "Waiting for service to reach steady state..."
aws ecs wait services-stable \
    --cluster spectrum-emulator-cluster-dev \
    --services spectrum-youtube-streaming \
    --region us-east-1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}🎉 ULTRA HD deployment completed successfully!${NC}"
else
    echo -e "${YELLOW}⚠️  Deployment may still be in progress. Check ECS console for status.${NC}"
fi

echo ""
echo -e "${PURPLE}🎬 === ULTRA HD STREAMING SPECS === 🎬${NC}"
echo -e "${CYAN}📐 Resolution:${NC} 1920x1080 @ 60fps"
echo -e "${CYAN}🎯 Video Bitrate:${NC} 8000k (8 Mbps) - YouTube Premium Quality"
echo -e "${CYAN}🎵 Audio Bitrate:${NC} 320k AAC Studio Quality"
echo -e "${CYAN}🎨 Scaling:${NC} 8x pixel-perfect with Lanczos filtering"
echo -e "${CYAN}🔄 Outputs:${NC} YouTube RTMP + S3 HLS simultaneously"
echo -e "${CYAN}💾 Resources:${NC} 4 vCPU / 8GB RAM"
echo ""

echo -e "${GREEN}🌐 Your ULTRA HD stream will be available at:${NC}"
echo -e "${BLUE}   Web Interface:${NC} https://d112s3ps8xh739.cloudfront.net"
echo -e "${BLUE}   YouTube Control:${NC} https://d112s3ps8xh739.cloudfront.net/youtube-stream-control.html"
echo -e "${BLUE}   HLS Stream:${NC} https://spectrum-emulator-stream-dev-043309319786.s3.us-east-1.amazonaws.com/hls/stream.m3u8"
echo ""

echo -e "${YELLOW}📊 To monitor the deployment:${NC}"
echo "aws ecs describe-services --cluster spectrum-emulator-cluster-dev --services spectrum-youtube-streaming --region us-east-1"
echo ""
echo "aws logs tail \"/ecs/spectrum-emulator-streaming\" --follow --region us-east-1"
echo ""

echo -e "${GREEN}🎮 Ready to stream ZX Spectrum games in glorious 1080p! 🎮${NC}"
echo -e "${PURPLE}The internet sadness is now replaced with ULTRA HD happiness! 🎉✨${NC}"
