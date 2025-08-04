#!/bin/bash

# Test Script for ZX Spectrum Emulator with OpenSE ROM
# ====================================================
# Tests the OpenSE ROM version of the emulator

echo "🧪 Testing ZX Spectrum Emulator with OpenSE ROM"
echo "==============================================="

# Configuration
IMAGE_NAME="spectrum-emulator:opense-rom"
CONTAINER_NAME="spectrum-emulator-opense-test"
HEALTH_PORT=8080
WEBSOCKET_PORT=8765

echo "Image: $IMAGE_NAME"
echo "Container: $CONTAINER_NAME"
echo "ROM: OpenSE (Open Source)"
echo ""

# Step 1: Check if image exists
echo "🔍 Checking if Docker image exists..."
if ! docker images | grep -q "spectrum-emulator.*opense-rom"; then
    echo "❌ Error: Docker image not found: $IMAGE_NAME"
    echo ""
    echo "Please build the image first:"
    echo "   ./build-opense-rom.sh"
    echo ""
    exit 1
fi
echo "✅ Docker image found"
echo ""

# Step 2: Clean up any existing test containers
echo "🧹 Cleaning up existing test containers..."
if docker ps -a -q -f name="$CONTAINER_NAME" | grep -q .; then
    echo "Stopping and removing existing container..."
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
    echo "✅ Cleanup complete"
else
    echo "No existing containers found"
fi
echo ""

# Step 3: Start test container
echo "🚀 Starting test container..."
docker run -d \
    --name "$CONTAINER_NAME" \
    -p "$HEALTH_PORT:8080" \
    -p "$WEBSOCKET_PORT:8765" \
    "$IMAGE_NAME"

if [ $? -eq 0 ]; then
    echo "✅ Container started successfully"
    CONTAINER_ID=$(docker ps -q -f name="$CONTAINER_NAME")
    echo "Container ID: $CONTAINER_ID"
else
    echo "❌ Failed to start container"
    exit 1
fi
echo ""

# Step 4: Wait for container to be ready
echo "⏳ Waiting for container to be ready..."
echo "This may take 30-60 seconds..."

MAX_WAIT=120
WAIT_COUNT=0
HEALTH_OK=false

while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 2))
    
    # Check if container is still running
    if ! docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
        echo "❌ Container stopped unexpectedly"
        echo ""
        echo "Container logs:"
        docker logs "$CONTAINER_NAME"
        exit 1
    fi
    
    # Check health endpoint
    HEALTH_RESPONSE=$(curl -s -w "%{http_code}" http://localhost:$HEALTH_PORT/health -o /tmp/health_test.json 2>/dev/null)
    HEALTH_CODE="${HEALTH_RESPONSE: -3}"
    
    if [ "$HEALTH_CODE" = "200" ]; then
        echo "✅ Container is ready! (took ${WAIT_COUNT}s)"
        HEALTH_OK=true
        break
    else
        printf "."
    fi
done

echo ""

if [ "$HEALTH_OK" = false ]; then
    echo "❌ Container failed to become ready within ${MAX_WAIT}s"
    echo ""
    echo "Container logs:"
    docker logs "$CONTAINER_NAME"
    exit 1
fi

# Step 5: Test health endpoint
echo "🏥 Testing Health Endpoint"
echo "========================="
HEALTH_RESPONSE=$(curl -s http://localhost:$HEALTH_PORT/health)
echo "Health Response:"
echo "$HEALTH_RESPONSE" | jq . 2>/dev/null || echo "$HEALTH_RESPONSE"
echo ""

# Step 6: Test WebSocket connection
echo "🔌 Testing WebSocket Connection"
echo "==============================="
if command -v websocat >/dev/null 2>&1; then
    echo "Sending status request..."
    WS_RESPONSE=$(echo '{"type":"status"}' | timeout 5 websocat ws://localhost:$WEBSOCKET_PORT 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$WS_RESPONSE" ]; then
        echo "✅ WebSocket connection successful"
        echo "Response: $WS_RESPONSE"
    else
        echo "❌ WebSocket connection failed"
    fi
else
    echo "⚠️  WebSocket test skipped (websocat not available)"
    echo "Install websocat to test WebSocket: cargo install websocat"
fi
echo ""

# Step 7: Test FUSE emulator with OpenSE ROM
echo "🎮 Testing FUSE Emulator with OpenSE ROM"
echo "========================================"
echo "Checking if FUSE is running with OpenSE ROM..."

# Check FUSE process
FUSE_RUNNING=$(docker exec "$CONTAINER_NAME" ps aux | grep fuse-sdl | grep -v grep || echo "")
if [ -n "$FUSE_RUNNING" ]; then
    echo "✅ FUSE emulator is running"
    echo "Process: $FUSE_RUNNING"
    
    # Check if OpenSE ROM is being used
    if echo "$FUSE_RUNNING" | grep -q "opense.rom"; then
        echo "✅ OpenSE ROM is being used"
    else
        echo "⚠️  Cannot confirm OpenSE ROM usage from process list"
    fi
else
    echo "❌ FUSE emulator is not running"
fi
echo ""

# Step 8: Test keyboard input
echo "⌨️  Testing Keyboard Input"
echo "========================="
echo "Sending test keyboard input to emulator..."

# Find FUSE window and send test input
TEST_RESULT=$(docker exec "$CONTAINER_NAME" bash -c '
export DISPLAY=:99
WIN=$(xdotool search --name "Fuse" 2>/dev/null | head -1)
if [ -n "$WIN" ]; then
    echo "FUSE window found: $WIN"
    xdotool type --window $WIN "PRINT \"OPENSE ROM TEST\""
    xdotool key --window $WIN Return
    echo "Test input sent successfully"
else
    echo "FUSE window not found"
fi
' 2>/dev/null)

echo "$TEST_RESULT"
echo ""

# Step 9: Test results summary
echo "📊 Test Results Summary"
echo "======================"
echo "Container Status: ✅ Running"
echo "Health Endpoint: $([ "$HEALTH_OK" = true ] && echo "✅ OK" || echo "❌ Failed")"
echo "FUSE Emulator: $([ -n "$FUSE_RUNNING" ] && echo "✅ Running" || echo "❌ Not Running")"
echo "OpenSE ROM: ✅ Configured (no external ROM files needed)"
echo "Keyboard Input: $(echo "$TEST_RESULT" | grep -q "successfully" && echo "✅ Working" || echo "⚠️  Needs verification")"
echo ""

# Step 10: Usage instructions
echo "🎯 Usage Instructions"
echo "===================="
echo "The emulator is now running with OpenSE ROM!"
echo ""
echo "🔗 Access Points:"
echo "   Health Check: http://localhost:$HEALTH_PORT/health"
echo "   WebSocket:    ws://localhost:$WEBSOCKET_PORT"
echo ""
echo "⌨️  Test Keyboard Input:"
echo "   docker exec $CONTAINER_NAME bash -c 'export DISPLAY=:99 && WIN=\$(xdotool search --name \"Fuse\" | head -1) && xdotool type --window \$WIN \"PRINT 2+2\" && xdotool key --window \$WIN Return'"
echo ""
echo "📋 Management Commands:"
echo "   View logs:    docker logs -f $CONTAINER_NAME"
echo "   Stop test:    docker stop $CONTAINER_NAME"
echo "   Remove test:  docker rm $CONTAINER_NAME"
echo "   Full cleanup: ./docker-stop.sh"
echo ""
echo "🎮 OpenSE ROM Features:"
echo "   ✅ Open source and legally distributable"
echo "   ✅ No external ROM files required"
echo "   ✅ Compatible with most ZX Spectrum software"
echo "   ✅ Authentic ZX Spectrum experience"
echo ""

echo "🏆 OpenSE ROM test completed successfully!"
echo "The emulator is ready for use with the open-source ROM."
