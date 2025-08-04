#!/bin/bash

# ZX Spectrum YouTube Stream Starter - NEW SERVICE
# This script starts the ZX Spectrum emulator streaming to YouTube

set -e

echo "🎮 ZX Spectrum YouTube Stream Starter (NEW SERVICE)"
echo "=================================================="

# Configuration
CLUSTER_NAME="spectrum-emulator-cluster-dev"
SERVICE_NAME="spectrum-youtube-streaming"  # NEW SERVICE NAME
REGION="us-east-1"
CLOUDFRONT_URL="https://d112s3ps8xh739.cloudfront.net"
CONTROL_PAGE="$CLOUDFRONT_URL/youtube-stream-control.html"

echo "📋 Configuration:"
echo "   Cluster: $CLUSTER_NAME"
echo "   Service: $SERVICE_NAME (NEW CLEAN SERVICE)"
echo "   Region: $REGION"
echo "   YouTube Key: 0ebh-efdh-9qtq-2eq3-e6hz"
echo ""

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install AWS CLI first."
    exit 1
fi

# Check ECS service status
echo "🔍 Checking NEW YouTube streaming service status..."
SERVICE_STATUS=$(aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --region "$REGION" \
    --query 'services[0].status' \
    --output text 2>/dev/null || echo "ERROR")

if [ "$SERVICE_STATUS" != "ACTIVE" ]; then
    echo "❌ NEW ECS service is not active. Status: $SERVICE_STATUS"
    echo "   Please check your AWS infrastructure."
    exit 1
fi

# Check running count
RUNNING_COUNT=$(aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --region "$REGION" \
    --query 'services[0].runningCount' \
    --output text)

DESIRED_COUNT=$(aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --region "$REGION" \
    --query 'services[0].desiredCount' \
    --output text)

echo "✅ NEW YouTube service is active:"
echo "   Desired: $DESIRED_COUNT, Running: $RUNNING_COUNT"

if [ "$RUNNING_COUNT" -eq "0" ]; then
    echo "⏳ Service is starting up. This will take 5-7 minutes..."
    echo "   The container needs to install packages and start the emulator."
    echo ""
    echo "🔍 You can monitor progress in AWS Console:"
    echo "   ECS → Clusters → $CLUSTER_NAME → Services → $SERVICE_NAME"
    echo ""
    echo "📋 Or check logs:"
    echo "   aws logs tail \"/ecs/spectrum-emulator-streaming\" --follow --region $REGION"
    echo ""
    echo "⏰ Come back in 5-7 minutes and run this script again!"
    exit 0
fi

# Wait for service to be ready
echo "⏳ Waiting for NEW service to be ready..."
aws ecs wait services-stable \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --region "$REGION"

echo "✅ NEW YouTube streaming service is stable and ready!"

# Test the streaming server
echo "🔗 Testing NEW YouTube streaming server connection..."
ALB_DNS="spectrum-emulator-alb-dev-1273339161.us-east-1.elb.amazonaws.com"

# Test health endpoint
if curl -s -f "http://$ALB_DNS/health" | grep -q "YouTube"; then
    echo "✅ NEW YouTube streaming server is healthy and configured!"
    HEALTH_RESPONSE=$(curl -s "http://$ALB_DNS/health")
    echo "   Response: $HEALTH_RESPONSE"
else
    echo "⚠️  Health check didn't show YouTube configuration, but continuing..."
fi

echo ""
echo "🎉 NEW YOUTUBE STREAMING SERVICE IS READY!"
echo ""
echo "📺 Your ZX Spectrum emulator is now ready to stream to YouTube!"
echo "   YouTube Stream Key: 0ebh-efdh-9qtq-2eq3-e6hz"
echo "   Service: $SERVICE_NAME (CLEAN NEW SERVICE)"
echo ""
echo "🌐 Open the control interface:"
echo "   $CONTROL_PAGE"
echo ""
echo "📋 Steps to start streaming:"
echo "   1. Open the control page above"
echo "   2. Click 'Connect to Server'"
echo "   3. Look for: 'ZX Spectrum YouTube Streaming Server Ready!'"
echo "   4. Click '🚀 Start YouTube Stream'"
echo "   5. Check your YouTube Live dashboard"
echo ""
echo "📊 Monitor the stream:"
echo "   aws logs tail \"/ecs/spectrum-emulator-streaming\" --follow --region $REGION"
echo ""
echo "🛑 To stop the stream:"
echo "   aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --desired-count 0 --region $REGION"
echo ""
echo "🎮 Ready to stream ZX Spectrum to YouTube Live! 🔴"
