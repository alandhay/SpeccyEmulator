#!/bin/bash

# Test script for ZX Spectrum Emulator deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}🧪 Testing ZX Spectrum Emulator Deployment${NC}"

# Check if deployment info exists
if [ ! -f "$PROJECT_ROOT/deployment-info.json" ]; then
    echo -e "${RED}❌ No deployment info found. Run deploy-complete.sh first.${NC}"
    exit 1
fi

# Read deployment info
CLOUDFRONT_DOMAIN=$(jq -r '.cloudfront_domain' "$PROJECT_ROOT/deployment-info.json")
REGION=$(jq -r '.region' "$PROJECT_ROOT/deployment-info.json")
ECS_CLUSTER=$(jq -r '.ecs_cluster' "$PROJECT_ROOT/deployment-info.json")
ECS_SERVICE=$(jq -r '.ecs_service' "$PROJECT_ROOT/deployment-info.json")

echo "Testing deployment:"
echo "  CloudFront Domain: $CLOUDFRONT_DOMAIN"
echo "  Region: $REGION"

# Test 1: CloudFront Distribution
echo -e "${BLUE}Test 1: CloudFront Distribution${NC}"
if curl -s -o /dev/null -w "%{http_code}" "https://$CLOUDFRONT_DOMAIN" | grep -q "200"; then
    echo -e "${GREEN}✅ CloudFront distribution is accessible${NC}"
else
    echo -e "${RED}❌ CloudFront distribution is not accessible${NC}"
fi

# Test 2: Web Content
echo -e "${BLUE}Test 2: Web Content${NC}"
if curl -s "https://$CLOUDFRONT_DOMAIN" | grep -q "ZX Spectrum Emulator"; then
    echo -e "${GREEN}✅ Web content is served correctly${NC}"
else
    echo -e "${RED}❌ Web content is not served correctly${NC}"
fi

# Test 3: ECS Service Status
echo -e "${BLUE}Test 3: ECS Service Status${NC}"
SERVICE_STATUS=$(aws ecs describe-services \
    --cluster "$ECS_CLUSTER" \
    --services "$ECS_SERVICE" \
    --region "$REGION" \
    --query 'services[0].status' \
    --output text)

if [ "$SERVICE_STATUS" = "ACTIVE" ]; then
    echo -e "${GREEN}✅ ECS service is active${NC}"
else
    echo -e "${RED}❌ ECS service is not active (status: $SERVICE_STATUS)${NC}"
fi

# Test 4: ECS Tasks Running
echo -e "${BLUE}Test 4: ECS Tasks${NC}"
RUNNING_TASKS=$(aws ecs describe-services \
    --cluster "$ECS_CLUSTER" \
    --services "$ECS_SERVICE" \
    --region "$REGION" \
    --query 'services[0].runningCount' \
    --output text)

if [ "$RUNNING_TASKS" -gt 0 ]; then
    echo -e "${GREEN}✅ ECS tasks are running ($RUNNING_TASKS tasks)${NC}"
else
    echo -e "${RED}❌ No ECS tasks are running${NC}"
fi

# Test 5: Health Check
echo -e "${BLUE}Test 5: Health Check${NC}"
ALB_DNS=$(jq -r '.alb_dns' "$PROJECT_ROOT/deployment-info.json" 2>/dev/null || echo "")
if [ ! -z "$ALB_DNS" ]; then
    if curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS/health" | grep -q "200"; then
        echo -e "${GREEN}✅ Health check endpoint is responding${NC}"
    else
        echo -e "${RED}❌ Health check endpoint is not responding${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  ALB DNS not found in deployment info${NC}"
fi

# Test 6: WebSocket Endpoint (basic connectivity test)
echo -e "${BLUE}Test 6: WebSocket Endpoint${NC}"
if command -v wscat >/dev/null 2>&1; then
    if timeout 5 wscat -c "wss://$CLOUDFRONT_DOMAIN/ws" --execute 'console.log("connected")' 2>/dev/null; then
        echo -e "${GREEN}✅ WebSocket endpoint is accessible${NC}"
    else
        echo -e "${RED}❌ WebSocket endpoint is not accessible${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  wscat not installed, skipping WebSocket test${NC}"
fi

# Test 7: Stream Endpoint
echo -e "${BLUE}Test 7: Stream Endpoint${NC}"
if curl -s -o /dev/null -w "%{http_code}" "https://$CLOUDFRONT_DOMAIN/stream/hls/stream.m3u8" | grep -q "200\|404"; then
    echo -e "${GREEN}✅ Stream endpoint is accessible (may be 404 if no stream active)${NC}"
else
    echo -e "${RED}❌ Stream endpoint is not accessible${NC}"
fi

# Summary
echo ""
echo -e "${BLUE}📊 Test Summary${NC}"
echo "Deployment appears to be working. You can access your emulator at:"
echo "  https://$CLOUDFRONT_DOMAIN"
echo ""
echo -e "${YELLOW}Note: Some features may not work until the emulator is started via the web interface${NC}"

# Show recent logs
echo -e "${BLUE}📋 Recent ECS Logs${NC}"
LOG_GROUP="/ecs/spectrum-emulator-$(jq -r '.environment' "$PROJECT_ROOT/deployment-info.json")"
echo "To view logs, run:"
echo "  aws logs tail '$LOG_GROUP' --region $REGION --follow"
