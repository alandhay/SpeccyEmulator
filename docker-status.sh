#!/bin/bash

# Docker Status Script - ZX Spectrum Emulator
# ===========================================
# Displays comprehensive report on all running containers

echo "📊 ZX Spectrum Emulator Docker Status Report"
echo "============================================="
echo "Generated: $(date)"
echo ""

# Configuration
CONTAINER_PATTERNS=("spectrum-emulator")
HEALTH_PORT=8080
WEBSOCKET_PORT=8765

# Step 1: Overall Docker Status
echo "🐳 Overall Docker Status"
echo "======================="
TOTAL_RUNNING=$(docker ps -q | wc -l)
TOTAL_CONTAINERS=$(docker ps -a -q | wc -l)
TOTAL_IMAGES=$(docker images -q | wc -l)

echo "System Overview:"
echo "   Running containers: $TOTAL_RUNNING"
echo "   Total containers: $TOTAL_CONTAINERS"
echo "   Total images: $TOTAL_IMAGES"
echo "   Docker version: $(docker --version 2>/dev/null || echo 'Unknown')"
echo ""

# Step 2: Spectrum Emulator Specific Status
echo "🎮 Spectrum Emulator Containers"
echo "==============================="

SPECTRUM_RUNNING=$(docker ps -q -f name=spectrum-emulator | wc -l)
SPECTRUM_TOTAL=$(docker ps -a -q -f name=spectrum-emulator | wc -l)

echo "Spectrum Containers:"
echo "   Running: $SPECTRUM_RUNNING"
echo "   Total: $SPECTRUM_TOTAL"
echo ""

if [ $SPECTRUM_TOTAL -eq 0 ]; then
    echo "✅ No spectrum emulator containers found"
    echo ""
    echo "💡 To start a container:"
    echo "   ./docker-start.sh"
    echo ""
else
    # Show running containers
    if [ $SPECTRUM_RUNNING -gt 0 ]; then
        echo "🟢 Running Containers:"
        echo "====================="
        docker ps -f name=spectrum-emulator --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.CreatedAt}}"
        echo ""
        
        # Detailed status for each running container
        RUNNING_IDS=$(docker ps -q -f name=spectrum-emulator)
        for container_id in $RUNNING_IDS; do
            CONTAINER_NAME=$(docker inspect --format='{{.Name}}' "$container_id" | sed 's/^.//')
            echo "📋 Container: $CONTAINER_NAME"
            echo "   ID: $container_id"
            echo "   Status: $(docker inspect --format='{{.State.Status}}' "$container_id")"
            echo "   Started: $(docker inspect --format='{{.State.StartedAt}}' "$container_id" | cut -d'T' -f1,2 | tr 'T' ' ')"
            echo "   Uptime: $(docker inspect --format='{{.State.StartedAt}}' "$container_id" | xargs -I {} date -d {} +%s | xargs -I {} echo $(($(date +%s) - {})) | xargs -I {} echo {} seconds)"
            
            # Health check
            echo "   Health Check:"
            HEALTH_RESPONSE=$(curl -s -w "%{http_code}" http://localhost:$HEALTH_PORT/health -o /tmp/health_status.json 2>/dev/null)
            HEALTH_CODE="${HEALTH_RESPONSE: -3}"
            
            if [ "$HEALTH_CODE" = "200" ]; then
                echo "      ✅ Health: OK (HTTP $HEALTH_CODE)"
                if command -v jq >/dev/null 2>&1 && [ -f /tmp/health_status.json ]; then
                    HEALTH_VERSION=$(jq -r '.version // "unknown"' /tmp/health_status.json 2>/dev/null)
                    HEALTH_STRATEGY=$(jq -r '.strategy // "unknown"' /tmp/health_status.json 2>/dev/null)
                    echo "      📦 Version: $HEALTH_VERSION"
                    echo "      🎯 Strategy: $HEALTH_STRATEGY"
                    
                    # Check if using OpenSE ROM
                    if echo "$CONTAINER_NAME" | grep -q "opense"; then
                        echo "      🎮 ROM: OpenSE (Open Source)"
                    fi
                    
                    # Process status
                    XVFB_STATUS=$(jq -r '.processes.xvfb // false' /tmp/health_status.json 2>/dev/null)
                    EMULATOR_STATUS=$(jq -r '.processes.emulator // false' /tmp/health_status.json 2>/dev/null)
                    FFMPEG_HLS_STATUS=$(jq -r '.processes.ffmpeg_hls // false' /tmp/health_status.json 2>/dev/null)
                    FFMPEG_YOUTUBE_STATUS=$(jq -r '.processes.ffmpeg_youtube // false' /tmp/health_status.json 2>/dev/null)
                    
                    echo "      🔧 Processes:"
                    echo "         Xvfb: $([ "$XVFB_STATUS" = "true" ] && echo "✅ Running" || echo "❌ Stopped")"
                    echo "         FUSE: $([ "$EMULATOR_STATUS" = "true" ] && echo "✅ Running" || echo "❌ Stopped")"
                    echo "         HLS: $([ "$FFMPEG_HLS_STATUS" = "true" ] && echo "✅ Running" || echo "❌ Stopped")"
                    echo "         YouTube: $([ "$FFMPEG_YOUTUBE_STATUS" = "true" ] && echo "✅ Running" || echo "❌ Stopped")"
                fi
            else
                echo "      ❌ Health: Failed (HTTP $HEALTH_CODE)"
            fi
            
            # WebSocket check
            echo "   WebSocket Check:"
            if command -v websocat >/dev/null 2>&1; then
                WS_RESPONSE=$(echo '{"type":"status"}' | timeout 3 websocat ws://localhost:$WEBSOCKET_PORT 2>/dev/null)
                if [ $? -eq 0 ] && [ -n "$WS_RESPONSE" ]; then
                    echo "      ✅ WebSocket: OK"
                else
                    echo "      ❌ WebSocket: Failed or timeout"
                fi
            else
                echo "      ⚠️  WebSocket: Cannot test (websocat not available)"
            fi
            
            # Resource usage
            echo "   Resource Usage:"
            STATS=$(docker stats --no-stream --format "{{.CPUPerc}}\t{{.MemUsage}}" "$container_id" 2>/dev/null)
            if [ -n "$STATS" ]; then
                CPU_USAGE=$(echo "$STATS" | cut -f1)
                MEM_USAGE=$(echo "$STATS" | cut -f2)
                echo "      🖥️  CPU: $CPU_USAGE"
                echo "      🧠 Memory: $MEM_USAGE"
            else
                echo "      ⚠️  Resource stats unavailable"
            fi
            
            echo ""
        done
    fi
    
    # Show stopped containers
    STOPPED_IDS=$(docker ps -a -q -f name=spectrum-emulator -f status=exited)
    if [ -n "$STOPPED_IDS" ]; then
        echo "🔴 Stopped Containers:"
        echo "====================="
        docker ps -a -f name=spectrum-emulator -f status=exited --format "table {{.Names}}\t{{.Status}}\t{{.CreatedAt}}"
        echo ""
        
        echo "💡 To view logs from stopped containers:"
        for container_id in $STOPPED_IDS; do
            CONTAINER_NAME=$(docker inspect --format='{{.Name}}' "$container_id" | sed 's/^.//')
            echo "   docker logs $CONTAINER_NAME"
        done
        echo ""
    fi
fi

# Step 3: Port Status
echo "🔌 Port Status"
echo "============="
echo "Checking key ports:"

# Check health port
if netstat -tuln 2>/dev/null | grep -q ":$HEALTH_PORT "; then
    echo "   Port $HEALTH_PORT (Health): 🟢 In use"
    HEALTH_PROCESS=$(netstat -tulnp 2>/dev/null | grep ":$HEALTH_PORT " | awk '{print $7}' | head -1)
    echo "      Process: ${HEALTH_PROCESS:-unknown}"
else
    echo "   Port $HEALTH_PORT (Health): ⚪ Available"
fi

# Check WebSocket port
if netstat -tuln 2>/dev/null | grep -q ":$WEBSOCKET_PORT "; then
    echo "   Port $WEBSOCKET_PORT (WebSocket): 🟢 In use"
    WS_PROCESS=$(netstat -tulnp 2>/dev/null | grep ":$WEBSOCKET_PORT " | awk '{print $7}' | head -1)
    echo "      Process: ${WS_PROCESS:-unknown}"
else
    echo "   Port $WEBSOCKET_PORT (WebSocket): ⚪ Available"
fi

echo ""

# Step 4: Image Status
echo "🖼️  Image Status"
echo "==============="
echo "Spectrum Emulator Images:"
SPECTRUM_IMAGES=$(docker images | grep spectrum-emulator)
if [ -n "$SPECTRUM_IMAGES" ]; then
    echo "$SPECTRUM_IMAGES" | while read line; do
        echo "   $line"
    done
else
    echo "   ❌ No spectrum emulator images found"
    echo ""
    echo "💡 To build an image:"
    echo "   ./build-golden-reference-v2-final.sh"
fi

echo ""

# Step 5: Quick Actions
echo "⚡ Quick Actions"
echo "==============="
if [ $SPECTRUM_RUNNING -eq 0 ]; then
    echo "🚀 Start container:     ./docker-start.sh"
else
    echo "🛑 Stop containers:     ./docker-stop.sh"
    echo "📋 View logs:           docker logs -f $(docker ps -q -f name=spectrum-emulator | head -1)"
    echo "🔗 Health check:        curl http://localhost:$HEALTH_PORT/health"
    echo "🔌 WebSocket test:      echo '{\"type\":\"status\"}' | websocat ws://localhost:$WEBSOCKET_PORT"
fi

echo "🔄 Refresh status:      ./docker-status.sh"
echo "🧹 Clean up:            docker system prune"

echo ""

# Step 6: Recommendations
echo "💡 Recommendations"
echo "=================="
if [ $SPECTRUM_RUNNING -eq 0 ]; then
    echo "✅ Ready to start a new container"
    echo "   Use './docker-start.sh' to begin"
elif [ $SPECTRUM_RUNNING -eq 1 ]; then
    # Check if the running container is healthy
    HEALTH_RESPONSE=$(curl -s -w "%{http_code}" http://localhost:$HEALTH_PORT/health -o /dev/null 2>/dev/null)
    HEALTH_CODE="${HEALTH_RESPONSE: -3}"
    
    if [ "$HEALTH_CODE" = "200" ]; then
        echo "✅ Container is running and healthy"
        echo "   Access points:"
        echo "   - Health: http://localhost:$HEALTH_PORT/health"
        echo "   - WebSocket: ws://localhost:$WEBSOCKET_PORT"
    else
        echo "⚠️  Container is running but may have issues"
        echo "   Check logs: docker logs -f $(docker ps -q -f name=spectrum-emulator | head -1)"
    fi
else
    echo "⚠️  Multiple containers running - this may cause conflicts"
    echo "   Consider stopping extras: ./docker-stop.sh"
fi

echo ""
echo "📊 Status report complete!"
echo "Last updated: $(date)"
