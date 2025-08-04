#!/bin/bash

# Docker Stop Script - ZX Spectrum Emulator
# =========================================
# Stops any currently running spectrum emulator containers

echo "🛑 Stopping ZX Spectrum Emulator Docker Containers"
echo "=================================================="

# Configuration
CONTAINER_PATTERNS=("spectrum-emulator" "spectrum-emulator-opense-test" "spectrum-emulator-final-test" "spectrum-emulator-golden-test")
STOPPED_COUNT=0
REMOVED_COUNT=0

echo "Looking for containers matching patterns:"
for pattern in "${CONTAINER_PATTERNS[@]}"; do
    echo "   - $pattern*"
done
echo ""

# Step 1: Find all matching containers
echo "🔍 Searching for running containers..."
RUNNING_CONTAINERS=$(docker ps -q -f name=spectrum-emulator)
ALL_CONTAINERS=$(docker ps -a -q -f name=spectrum-emulator)

if [ -z "$RUNNING_CONTAINERS" ] && [ -z "$ALL_CONTAINERS" ]; then
    echo "✅ No spectrum emulator containers found"
    echo ""
    echo "📊 Current Docker Status:"
    echo "   Running containers: $(docker ps -q | wc -l)"
    echo "   Total containers: $(docker ps -a -q | wc -l)"
    exit 0
fi

echo "Found containers:"
if [ -n "$RUNNING_CONTAINERS" ]; then
    echo "   Running: $(echo $RUNNING_CONTAINERS | wc -w)"
    docker ps -f name=spectrum-emulator --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
fi

if [ -n "$ALL_CONTAINERS" ]; then
    STOPPED_CONTAINERS=$(docker ps -a -q -f name=spectrum-emulator -f status=exited)
    if [ -n "$STOPPED_CONTAINERS" ]; then
        echo "   Stopped: $(echo $STOPPED_CONTAINERS | wc -w)"
        docker ps -a -f name=spectrum-emulator -f status=exited --format "table {{.Names}}\t{{.Status}}"
    fi
fi

echo ""

# Step 2: Stop running containers
if [ -n "$RUNNING_CONTAINERS" ]; then
    echo "🛑 Stopping running containers..."
    
    for container_id in $RUNNING_CONTAINERS; do
        CONTAINER_NAME=$(docker inspect --format='{{.Name}}' "$container_id" | sed 's/^.//')
        echo "Stopping: $CONTAINER_NAME ($container_id)"
        
        # Try graceful stop first
        if docker stop "$container_id" >/dev/null 2>&1; then
            echo "   ✅ Stopped gracefully"
            STOPPED_COUNT=$((STOPPED_COUNT + 1))
        else
            echo "   ⚠️  Graceful stop failed, trying force kill..."
            if docker kill "$container_id" >/dev/null 2>&1; then
                echo "   ✅ Force killed"
                STOPPED_COUNT=$((STOPPED_COUNT + 1))
            else
                echo "   ❌ Failed to stop"
            fi
        fi
    done
    
    echo ""
    echo "✅ Stopped $STOPPED_COUNT container(s)"
else
    echo "No running containers to stop"
fi

echo ""

# Step 3: Ask about removing stopped containers
if [ -n "$ALL_CONTAINERS" ]; then
    echo "🗑️  Container Cleanup Options:"
    echo "   1. Remove all stopped spectrum emulator containers"
    echo "   2. Keep stopped containers (for log inspection)"
    echo "   3. Show container details first"
    echo ""
    
    read -p "Choose option (1/2/3) [default: 2]: " -n 1 -r
    echo
    
    case $REPLY in
        1|Y|y)
            echo ""
            echo "🗑️  Removing stopped containers..."
            
            for container_id in $ALL_CONTAINERS; do
                CONTAINER_NAME=$(docker inspect --format='{{.Name}}' "$container_id" 2>/dev/null | sed 's/^.//' || echo "unknown")
                CONTAINER_STATUS=$(docker inspect --format='{{.State.Status}}' "$container_id" 2>/dev/null || echo "unknown")
                
                if [ "$CONTAINER_STATUS" != "running" ]; then
                    echo "Removing: $CONTAINER_NAME ($container_id)"
                    if docker rm "$container_id" >/dev/null 2>&1; then
                        echo "   ✅ Removed"
                        REMOVED_COUNT=$((REMOVED_COUNT + 1))
                    else
                        echo "   ❌ Failed to remove"
                    fi
                fi
            done
            
            echo ""
            echo "✅ Removed $REMOVED_COUNT container(s)"
            ;;
        3)
            echo ""
            echo "📊 Container Details:"
            echo "==================="
            docker ps -a -f name=spectrum-emulator --format "table {{.Names}}\t{{.Status}}\t{{.CreatedAt}}\t{{.Size}}"
            echo ""
            echo "💡 To remove containers later, run: docker rm <container_name>"
            ;;
        *)
            echo ""
            echo "✅ Keeping stopped containers for inspection"
            echo "💡 To view logs: docker logs <container_name>"
            echo "💡 To remove later: docker rm <container_name>"
            ;;
    esac
fi

echo ""

# Step 4: Final status report
echo "📊 Final Status Report"
echo "====================="

REMAINING_RUNNING=$(docker ps -q -f name=spectrum-emulator | wc -l)
REMAINING_TOTAL=$(docker ps -a -q -f name=spectrum-emulator | wc -l)

echo "Spectrum Emulator Containers:"
echo "   Running: $REMAINING_RUNNING"
echo "   Total: $REMAINING_TOTAL"

if [ $REMAINING_RUNNING -eq 0 ]; then
    echo "   ✅ All spectrum emulator containers stopped"
else
    echo "   ⚠️  Some containers may still be running:"
    docker ps -f name=spectrum-emulator --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
fi

echo ""
echo "Overall Docker Status:"
echo "   All running containers: $(docker ps -q | wc -l)"
echo "   All containers: $(docker ps -a -q | wc -l)"

# Step 5: Cleanup suggestions
echo ""
echo "🧹 Cleanup Suggestions:"
if [ $REMAINING_TOTAL -gt 0 ]; then
    echo "   Remove all stopped: docker container prune"
fi
echo "   Remove unused images: docker image prune"
echo "   Full system cleanup: docker system prune"

echo ""
echo "🎮 ZX Spectrum Emulator containers have been stopped!"
echo "Use './docker-start.sh' to start a fresh container."
