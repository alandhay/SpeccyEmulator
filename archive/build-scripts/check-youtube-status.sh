#!/bin/bash

# Simple YouTube Streaming Status Checker

CLUSTER_NAME="spectrum-emulator-cluster-dev"
SERVICE_NAME="spectrum-youtube-streaming"
REGION="us-east-1"

echo "📊 YouTube Streaming Service Status"
echo "=================================="

# Get service status
RUNNING_COUNT=$(aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --region "$REGION" \
    --query 'services[0].runningCount' \
    --output text 2>/dev/null || echo "0")

DESIRED_COUNT=$(aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --region "$REGION" \
    --query 'services[0].desiredCount' \
    --output text 2>/dev/null || echo "0")

echo "Service: $SERVICE_NAME"
echo "Desired: $DESIRED_COUNT"
echo "Running: $RUNNING_COUNT"

if [ "$RUNNING_COUNT" -eq "1" ]; then
    echo "✅ SERVICE IS READY!"
    echo ""
    echo "🌐 Open: https://d112s3ps8xh739.cloudfront.net/youtube-stream-control.html"
    echo "📺 Look for: 'ZX Spectrum YouTube Streaming Server Ready!'"
    echo "🚀 Click: 'Start YouTube Stream'"
    
    # Test health endpoint
    echo ""
    echo "🔍 Testing connection..."
    HEALTH=$(curl -s "http://spectrum-emulator-alb-dev-1273339161.us-east-1.elb.amazonaws.com/health" 2>/dev/null || echo "Connection failed")
    echo "Health: $HEALTH"
    
elif [ "$RUNNING_COUNT" -eq "0" ]; then
    echo "⏳ SERVICE IS STARTING UP..."
    echo "   This takes 5-7 minutes for first startup"
    echo "   Run this script again in a few minutes"
else
    echo "🔄 SERVICE IS TRANSITIONING..."
    echo "   Wait a moment and try again"
fi

echo ""
echo "📋 Monitor logs: aws logs tail \"/ecs/spectrum-emulator-streaming\" --follow --region us-east-1"
