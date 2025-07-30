#!/bin/bash

# ZX Spectrum Emulator Startup Script
# This script starts all components needed for the emulator

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

echo -e "${BLUE}🎮 Starting ZX Spectrum Emulator${NC}"
echo "Project root: $PROJECT_ROOT"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if port is in use
port_in_use() {
    lsof -i :$1 >/dev/null 2>&1
}

# Function to kill process on port
kill_port() {
    local port=$1
    local pid=$(lsof -t -i:$port 2>/dev/null)
    if [ ! -z "$pid" ]; then
        echo -e "${YELLOW}Killing process on port $port (PID: $pid)${NC}"
        kill -9 $pid 2>/dev/null || true
        sleep 1
    fi
}

# Check dependencies
echo -e "${BLUE}Checking dependencies...${NC}"

if ! command_exists fuse; then
    echo -e "${RED}❌ FUSE emulator not found. Installing...${NC}"
    sudo apt-get update
    sudo apt-get install -y fuse-emulator-sdl
fi

if ! command_exists ffmpeg; then
    echo -e "${RED}❌ FFmpeg not found. Installing...${NC}"
    sudo apt-get update
    sudo apt-get install -y ffmpeg
fi

if ! command_exists python3; then
    echo -e "${RED}❌ Python3 not found. Please install Python 3.8+${NC}"
    exit 1
fi

# Check if we have a display
if [ -z "$DISPLAY" ]; then
    echo -e "${YELLOW}⚠️  No DISPLAY variable set. Setting to :0${NC}"
    export DISPLAY=:0
fi

# Check if X11 is running
if ! xset q &>/dev/null; then
    echo -e "${RED}❌ X11 server not running. Please start X11 first.${NC}"
    echo "You can start X11 with: startx"
    exit 1
fi

echo -e "${GREEN}✅ All dependencies found${NC}"

# Create necessary directories
echo -e "${BLUE}Creating directories...${NC}"
mkdir -p "$PROJECT_ROOT/logs"
mkdir -p "$PROJECT_ROOT/stream/hls"
mkdir -p "$PROJECT_ROOT/games"

# Kill any existing processes
echo -e "${BLUE}Cleaning up existing processes...${NC}"
kill_port 8765  # WebSocket server
kill_port 8080  # HTTP server

# Kill any existing FUSE or FFmpeg processes
pkill -f "fuse" 2>/dev/null || true
pkill -f "ffmpeg.*x11grab" 2>/dev/null || true

# Activate virtual environment
echo -e "${BLUE}Activating Python virtual environment...${NC}"
cd "$PROJECT_ROOT"

if [ ! -d "venv" ]; then
    echo -e "${YELLOW}Creating virtual environment...${NC}"
    python3 -m venv venv
fi

source venv/bin/activate

# Install Python dependencies
echo -e "${BLUE}Installing Python dependencies...${NC}"
pip install -q -r server/requirements.txt

# Start HTTP server for web interface
echo -e "${BLUE}Starting HTTP server...${NC}"
cd "$PROJECT_ROOT/web"
python3 -m http.server 8080 &
HTTP_PID=$!
echo "HTTP server started (PID: $HTTP_PID)"

# Wait a moment for HTTP server to start
sleep 2

# Start WebSocket server
echo -e "${BLUE}Starting WebSocket server...${NC}"
cd "$PROJECT_ROOT"
python3 server/emulator_server.py &
WS_PID=$!
echo "WebSocket server started (PID: $WS_PID)"

# Wait a moment for WebSocket server to start
sleep 3

# Create PID file for cleanup
echo "$HTTP_PID" > "$PROJECT_ROOT/logs/http.pid"
echo "$WS_PID" > "$PROJECT_ROOT/logs/websocket.pid"

# Function to cleanup on exit
cleanup() {
    echo -e "\n${YELLOW}Shutting down emulator...${NC}"
    
    # Kill HTTP server
    if [ -f "$PROJECT_ROOT/logs/http.pid" ]; then
        HTTP_PID=$(cat "$PROJECT_ROOT/logs/http.pid")
        kill $HTTP_PID 2>/dev/null || true
        rm -f "$PROJECT_ROOT/logs/http.pid"
    fi
    
    # Kill WebSocket server
    if [ -f "$PROJECT_ROOT/logs/websocket.pid" ]; then
        WS_PID=$(cat "$PROJECT_ROOT/logs/websocket.pid")
        kill $WS_PID 2>/dev/null || true
        rm -f "$PROJECT_ROOT/logs/websocket.pid"
    fi
    
    # Kill FUSE and FFmpeg
    pkill -f "fuse" 2>/dev/null || true
    pkill -f "ffmpeg.*x11grab" 2>/dev/null || true
    
    echo -e "${GREEN}✅ Cleanup complete${NC}"
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Check if servers started successfully
sleep 2

if port_in_use 8080 && port_in_use 8765; then
    echo -e "${GREEN}✅ All servers started successfully!${NC}"
    echo ""
    echo -e "${GREEN}🎮 ZX Spectrum Emulator is ready!${NC}"
    echo ""
    echo -e "${BLUE}Web Interface:${NC} http://localhost:8080"
    echo -e "${BLUE}WebSocket Server:${NC} ws://localhost:8765"
    echo ""
    echo -e "${YELLOW}Instructions:${NC}"
    echo "1. Open http://localhost:8080 in your web browser"
    echo "2. Click 'Start Emulator' to begin"
    echo "3. Use the on-screen keyboard or your physical keyboard"
    echo "4. Press Ctrl+C to stop the emulator"
    echo ""
    
    # Wait for user interrupt
    echo -e "${BLUE}Press Ctrl+C to stop the emulator${NC}"
    while true; do
        sleep 1
    done
else
    echo -e "${RED}❌ Failed to start servers${NC}"
    cleanup
    exit 1
fi
