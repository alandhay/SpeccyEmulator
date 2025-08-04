#!/bin/bash

# Docker Start Script - ZX Spectrum Emulator
# ==========================================
# Kills any previous containers and starts a fresh one

echo "🚀 Starting ZX Spectrum Emulator Docker Container"
echo "================================================="

# Configuration
IMAGE_NAME="spectrum-emulator:opense-rom"
CONTAINER_NAME="spectrum-emulator-opense-test"
HEALTH_PORT=8080
WEBSOCKET_PORT=8765

echo "Image: $IMAGE_NAME"
echo "Container: $CONTAINER_NAME"
echo "Ports: $HEALTH_PORT (health), $WEBSOCKET_PORT (websocket)"
echo ""

# Step 1: Kill any existing containers with the same name
echo "🧹 Cleaning up any existing containers..."
if docker ps -a -q -f name="$CONTAINER_NAME" | grep -q .; then
    echo "Found existing container(s) with name: $CONTAINER_NAME"
    
    # Stop if running
    if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
        echo "Stopping running container..."
        docker stop "$CONTAINER_NAME" 2>/dev/null || true
    fi
    
    # Remove container
    echo "Removing existing container..."
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
    
    echo "✅ Cleanup complete"
else
    echo "No existing containers found"
fi

echo ""

# Step 2: Check if image exists
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

# Step 3: Check for port conflicts
echo "🔌 Checking for port conflicts..."
PORT_CONFLICTS=false

if netstat -tuln 2>/dev/null | grep -q ":$HEALTH_PORT "; then
    echo "⚠️  Warning: Port $HEALTH_PORT is already in use"
    PORT_CONFLICTS=true
fi

if netstat -tuln 2>/dev/null | grep -q ":$WEBSOCKET_PORT "; then
    echo "⚠️  Warning: Port $WEBSOCKET_PORT is already in use"
    PORT_CONFLICTS=true
fi

if [ "$PORT_CONFLICTS" = true ]; then
    echo ""
    echo "❌ Port conflicts detected. Please stop other services or use different ports."
    echo "Current port usage:"
    netstat -tuln 2>/dev/null | grep -E ":($HEALTH_PORT|$WEBSOCKET_PORT) " || echo "No conflicts found"
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted by user"
        exit 1
    fi
else
    echo "✅ Ports are available"
fi

echo ""

# Step 4: Start the new container
echo "🚀 Starting new container..."
echo "Command: docker run -d --name $CONTAINER_NAME -p $HEALTH_PORT:8080 -p $WEBSOCKET_PORT:8765 $IMAGE_NAME"
echo ""

docker run -d \
    --name "$CONTAINER_NAME" \
    -p "$HEALTH_PORT:8080" \
    -p "$WEBSOCKET_PORT:8765" \
    "$IMAGE_NAME"

START_EXIT_CODE=$?

if [ $START_EXIT_CODE -eq 0 ]; then
    CONTAINER_ID=$(docker ps -q -f name="$CONTAINER_NAME")
    
    if [ -n "$CONTAINER_ID" ]; then
        echo "✅ Container started successfully!"
        echo "Container ID: $CONTAINER_ID"
        echo ""
        echo "📊 Container Status:"
        docker ps -f name="$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""
        echo "🔗 Access Points:"
        echo "   Health Check: http://localhost:$HEALTH_PORT/health"
        echo "   WebSocket:    ws://localhost:$WEBSOCKET_PORT"
        echo ""
        echo "📋 Useful Commands:"
        echo "   View logs:    docker logs -f $CONTAINER_NAME"
        echo "   Stop:         ./docker-stop.sh"
        echo "   Status:       ./docker-status.sh"
        echo ""
        echo "⏳ Container is starting up... (may take 30-60 seconds to be fully ready)"
        echo "   Use './docker-status.sh' to monitor progress"
        
    else
        echo "❌ Container failed to start (not found in running containers)"
        echo ""
        echo "🔍 Checking container logs:"
        docker logs "$CONTAINER_NAME" 2>/dev/null || echo "No logs available"
        exit 1
    fi
else
    echo "❌ Failed to start container (exit code: $START_EXIT_CODE)"
    echo ""
    echo "🔍 Possible issues:"
    echo "   1. Image not found or corrupted"
    echo "   2. Port conflicts"
    echo "   3. Docker daemon issues"
    echo "   4. Insufficient resources"
    exit $START_EXIT_CODE
fi

echo ""
echo "🎮 ZX Spectrum Emulator Docker container is starting!"
echo "Use './docker-status.sh' to check when it's fully ready."
