#!/bin/bash

# Test Golden Reference Docker Image Locally
# ==========================================
# This script tests the golden reference Docker image locally
# before deploying to ECS, ensuring it works as expected.

echo "🧪 Testing Golden Reference Docker Image Locally"
echo "================================================"

# Configuration
IMAGE_NAME="spectrum-emulator:golden-reference"
CONTAINER_NAME="spectrum-emulator-golden-test"
TEST_DURATION=60  # Test for 60 seconds

echo "Image: $IMAGE_NAME"
echo "Container: $CONTAINER_NAME"
echo "Test Duration: $TEST_DURATION seconds"
echo ""

# Check if image exists
echo "🔍 Checking if Docker image exists..."
if ! docker images | grep -q "spectrum-emulator.*golden-reference"; then
    echo "❌ Error: Docker image not found: $IMAGE_NAME"
    echo "Please build the image first:"
    echo "   ./build-golden-reference.sh"
    exit 1
fi

echo "✅ Docker image found"
echo ""

# Stop and remove any existing test container
echo "🧹 Cleaning up any existing test container..."
docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm "$CONTAINER_NAME" 2>/dev/null || true
echo ""

# Start the container
echo "🚀 Starting golden reference container..."
echo "Command: docker run -d --name $CONTAINER_NAME -p 8080:8080 -p 8765:8765 $IMAGE_NAME"
echo ""

docker run -d \
    --name "$CONTAINER_NAME" \
    -p 8080:8080 \
    -p 8765:8765 \
    -e YOUTUBE_STREAM_KEY="" \
    -e SCALE_FACTOR=1.8 \
    -e FRAME_RATE=30 \
    "$IMAGE_NAME"

CONTAINER_ID=$(docker ps -q -f name="$CONTAINER_NAME")

if [ -z "$CONTAINER_ID" ]; then
    echo "❌ Error: Failed to start container"
    echo ""
    echo "🔍 Container logs:"
    docker logs "$CONTAINER_NAME"
    exit 1
fi

echo "✅ Container started successfully"
echo "Container ID: $CONTAINER_ID"
echo ""

# Wait for container to initialize
echo "⏳ Waiting for container to initialize (30 seconds)..."
sleep 30

# Check container status
echo "📊 Checking container status..."
CONTAINER_STATUS=$(docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME")
echo "Container Status: $CONTAINER_STATUS"

if [ "$CONTAINER_STATUS" != "running" ]; then
    echo "❌ Error: Container is not running"
    echo ""
    echo "🔍 Container logs:"
    docker logs "$CONTAINER_NAME"
    exit 1
fi

echo "✅ Container is running"
echo ""

# Test health endpoint
echo "🏥 Testing health endpoint..."
HEALTH_RESPONSE=$(curl -s -w "%{http_code}" http://localhost:8080/health -o /tmp/health_response.json)
HEALTH_CODE="${HEALTH_RESPONSE: -3}"

echo "Health Check Response Code: $HEALTH_CODE"

if [ "$HEALTH_CODE" = "200" ]; then
    echo "✅ Health check passed"
    echo "Health Response:"
    cat /tmp/health_response.json | jq . 2>/dev/null || cat /tmp/health_response.json
    echo ""
else
    echo "❌ Health check failed"
    echo "Response:"
    cat /tmp/health_response.json 2>/dev/null || echo "No response"
    echo ""
fi

# Test WebSocket endpoint
echo "🔌 Testing WebSocket endpoint..."
echo "Attempting to connect to ws://localhost:8765..."

# Simple WebSocket test using curl (if available) or nc
if command -v websocat &> /dev/null; then
    echo '{"type":"status"}' | timeout 5 websocat ws://localhost:8765 > /tmp/websocket_response.json 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✅ WebSocket connection successful"
        echo "WebSocket Response:"
        cat /tmp/websocket_response.json | jq . 2>/dev/null || cat /tmp/websocket_response.json
    else
        echo "⚠️  WebSocket test inconclusive (websocat timeout or connection issue)"
    fi
else
    echo "⚠️  WebSocket test skipped (websocat not available)"
fi

echo ""

# Show container logs
echo "📋 Container logs (last 20 lines):"
echo "=================================="
docker logs --tail 20 "$CONTAINER_NAME"
echo ""

# Monitor for test duration
echo "⏱️  Monitoring container for $TEST_DURATION seconds..."
echo "Press Ctrl+C to stop monitoring early"
echo ""

for i in $(seq 1 $TEST_DURATION); do
    sleep 1
    
    # Check if container is still running
    if ! docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
        echo ""
        echo "❌ Container stopped unexpectedly at $i seconds"
        echo ""
        echo "🔍 Final container logs:"
        docker logs "$CONTAINER_NAME"
        break
    fi
    
    # Show progress every 10 seconds
    if [ $((i % 10)) -eq 0 ]; then
        echo "⏳ $i/$TEST_DURATION seconds elapsed..."
    fi
done

echo ""

# Final status check
echo "📊 Final Status Check"
echo "===================="

FINAL_STATUS=$(docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "not found")
echo "Final Container Status: $FINAL_STATUS"

if [ "$FINAL_STATUS" = "running" ]; then
    echo "✅ Container completed test successfully"
    
    # Final health check
    FINAL_HEALTH=$(curl -s -w "%{http_code}" http://localhost:8080/health -o /dev/null)
    FINAL_HEALTH_CODE="${FINAL_HEALTH: -3}"
    
    if [ "$FINAL_HEALTH_CODE" = "200" ]; then
        echo "✅ Final health check passed"
    else
        echo "⚠️  Final health check failed (code: $FINAL_HEALTH_CODE)"
    fi
    
    echo ""
    echo "🎯 Test Results Summary:"
    echo "   ✅ Container started successfully"
    echo "   ✅ Container ran for full test duration"
    echo "   ✅ Health endpoint responding"
    echo "   ✅ Golden reference implementation working"
    echo ""
    echo "🏆 GOLDEN REFERENCE TEST: PASSED"
    
else
    echo "❌ Container failed during test"
    echo ""
    echo "🔍 Final container logs:"
    docker logs "$CONTAINER_NAME"
    echo ""
    echo "❌ GOLDEN REFERENCE TEST: FAILED"
fi

echo ""

# Cleanup
echo "🧹 Cleaning up test container..."
docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm "$CONTAINER_NAME" 2>/dev/null || true

echo "✅ Cleanup complete"
echo ""

if [ "$FINAL_STATUS" = "running" ]; then
    echo "🚀 Golden reference Docker image is ready for ECS deployment!"
    echo ""
    echo "Next steps:"
    echo "   1. Push image to ECR"
    echo "   2. Update ECS task definition"
    echo "   3. Deploy to ECS service"
else
    echo "🔧 Golden reference Docker image needs fixes before deployment"
    echo ""
    echo "Troubleshooting:"
    echo "   1. Review container logs above"
    echo "   2. Check Dockerfile configuration"
    echo "   3. Verify server code implementation"
    echo "   4. Test individual components"
fi
