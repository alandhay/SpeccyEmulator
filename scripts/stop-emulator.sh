#!/bin/bash

# ZX Spectrum Emulator Stop Script

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🛑 Stopping ZX Spectrum Emulator${NC}"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Function to kill process on port
kill_port() {
    local port=$1
    local pid=$(lsof -t -i:$port 2>/dev/null)
    if [ ! -z "$pid" ]; then
        echo -e "${YELLOW}Killing process on port $port (PID: $pid)${NC}"
        kill -9 $pid 2>/dev/null || true
        sleep 1
        echo -e "${GREEN}✅ Process on port $port stopped${NC}"
    else
        echo -e "${BLUE}ℹ️  No process running on port $port${NC}"
    fi
}

# Kill servers
echo -e "${BLUE}Stopping servers...${NC}"
kill_port 8765  # WebSocket server
kill_port 8080  # HTTP server

# Kill PID file processes
if [ -f "$PROJECT_ROOT/logs/http.pid" ]; then
    HTTP_PID=$(cat "$PROJECT_ROOT/logs/http.pid")
    if kill -0 $HTTP_PID 2>/dev/null; then
        echo -e "${YELLOW}Stopping HTTP server (PID: $HTTP_PID)${NC}"
        kill $HTTP_PID 2>/dev/null || true
    fi
    rm -f "$PROJECT_ROOT/logs/http.pid"
fi

if [ -f "$PROJECT_ROOT/logs/websocket.pid" ]; then
    WS_PID=$(cat "$PROJECT_ROOT/logs/websocket.pid")
    if kill -0 $WS_PID 2>/dev/null; then
        echo -e "${YELLOW}Stopping WebSocket server (PID: $WS_PID)${NC}"
        kill $WS_PID 2>/dev/null || true
    fi
    rm -f "$PROJECT_ROOT/logs/websocket.pid"
fi

# Kill FUSE emulator
echo -e "${BLUE}Stopping FUSE emulator...${NC}"
if pkill -f "fuse" 2>/dev/null; then
    echo -e "${GREEN}✅ FUSE emulator stopped${NC}"
else
    echo -e "${BLUE}ℹ️  FUSE emulator not running${NC}"
fi

# Kill FFmpeg processes
echo -e "${BLUE}Stopping video streaming...${NC}"
if pkill -f "ffmpeg.*x11grab" 2>/dev/null; then
    echo -e "${GREEN}✅ Video streaming stopped${NC}"
else
    echo -e "${BLUE}ℹ️  Video streaming not running${NC}"
fi

# Clean up stream files
echo -e "${BLUE}Cleaning up stream files...${NC}"
rm -f "$PROJECT_ROOT/stream/hls/"*.ts
rm -f "$PROJECT_ROOT/stream/hls/"*.m3u8

echo -e "${GREEN}✅ ZX Spectrum Emulator stopped successfully${NC}"
