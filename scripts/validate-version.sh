#!/bin/bash

# Version Validation Script for ZX Spectrum Emulator
# Usage: ./validate-version.sh [expected_version]

set -e

EXPECTED_VERSION=${1:-"1.0.0-asyncio-fixed"}
HEALTH_URL="https://d112s3ps8xh739.cloudfront.net/health"
VERSION_URL="https://d112s3ps8xh739.cloudfront.net/version"

echo "🔍 Validating ZX Spectrum Emulator Version..."
echo "Expected Version: $EXPECTED_VERSION"
echo ""

# Check health endpoint
echo "📊 Checking health endpoint..."
HEALTH_RESPONSE=$(curl -s "$HEALTH_URL" || echo "ERROR")

if [[ "$HEALTH_RESPONSE" == "ERROR" ]]; then
    echo "❌ Health endpoint unreachable"
    exit 1
fi

echo "✅ Health endpoint responding"

# Extract version from health response
ACTUAL_VERSION=$(echo "$HEALTH_RESPONSE" | jq -r '.version.version' 2>/dev/null || echo "UNKNOWN")
BUILD_TIME=$(echo "$HEALTH_RESPONSE" | jq -r '.version.build_time' 2>/dev/null || echo "UNKNOWN")
BUILD_HASH=$(echo "$HEALTH_RESPONSE" | jq -r '.version.build_hash' 2>/dev/null || echo "UNKNOWN")
UPTIME=$(echo "$HEALTH_RESPONSE" | jq -r '.version.uptime' 2>/dev/null || echo "UNKNOWN")

echo ""
echo "📋 Current Deployment Info:"
echo "  Version: $ACTUAL_VERSION"
echo "  Build Time: $BUILD_TIME"
echo "  Build Hash: $BUILD_HASH"
echo "  Uptime: ${UPTIME}s"
echo ""

# Validate version
if [[ "$ACTUAL_VERSION" == "$EXPECTED_VERSION" ]]; then
    echo "✅ Version validation PASSED"
    echo "🎯 Deployed version matches expected version"
else
    echo "❌ Version validation FAILED"
    echo "🚨 Expected: $EXPECTED_VERSION"
    echo "🚨 Actual: $ACTUAL_VERSION"
    exit 1
fi

# Check ECS service status
echo ""
echo "🔍 Checking ECS service status..."
SERVICE_STATUS=$(aws ecs describe-services \
    --cluster spectrum-emulator-cluster-dev \
    --services spectrum-youtube-streaming \
    --region us-east-1 \
    --query 'services[0].{runningCount:runningCount,desiredCount:desiredCount,taskDefinition:taskDefinition}' \
    --output json 2>/dev/null || echo "ERROR")

if [[ "$SERVICE_STATUS" != "ERROR" ]]; then
    RUNNING_COUNT=$(echo "$SERVICE_STATUS" | jq -r '.runningCount')
    DESIRED_COUNT=$(echo "$SERVICE_STATUS" | jq -r '.desiredCount')
    TASK_DEF=$(echo "$SERVICE_STATUS" | jq -r '.taskDefinition' | sed 's/.*://')
    
    echo "  Running Tasks: $RUNNING_COUNT/$DESIRED_COUNT"
    echo "  Task Definition: $TASK_DEF"
    
    if [[ "$RUNNING_COUNT" == "$DESIRED_COUNT" ]]; then
        echo "✅ ECS service healthy"
    else
        echo "⚠️  ECS service not at desired capacity"
    fi
else
    echo "⚠️  Could not check ECS service status"
fi

echo ""
echo "🎮 Test the emulator at: https://d112s3ps8xh739.cloudfront.net"
echo "📊 Monitor logs at: https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#logsV2:log-groups/log-group/\$252Fecs\$252Fspectrum-emulator-streaming"
echo ""
echo "✨ Version validation complete!"
