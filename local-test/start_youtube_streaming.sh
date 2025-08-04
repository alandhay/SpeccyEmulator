#!/bin/bash

# Start Local ZX Spectrum Emulator with YouTube Streaming
# Uses your YouTube stream key: 0ebh-efdh-9qtq-2eq3-e6hz

echo "🎮 Starting ZX Spectrum Emulator with YouTube Live Streaming"
echo "============================================================"

# Set YouTube stream key
export YOUTUBE_STREAM_KEY="0ebh-efdh-9qtq-2eq3-e6hz"

# Navigate to local test directory
cd /home/ubuntu/workspace/SpeccyEmulator/local-test

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv venv
    source venv/bin/activate
    pip install websockets aiohttp asyncio
else
    echo "Activating Python virtual environment..."
    source venv/bin/activate
fi

# Kill any existing processes
echo "Cleaning up existing processes..."
pkill -f "local_server_headless_fixed.py" 2>/dev/null || true
pkill -f "fuse-sdl" 2>/dev/null || true
pkill -f "Xvfb :99" 2>/dev/null || true
pkill -f "ffmpeg.*youtube" 2>/dev/null || true

# Wait a moment for cleanup
sleep 2

echo ""
echo "🔧 Configuration:"
echo "   YouTube Stream Key: $YOUTUBE_STREAM_KEY"
echo "   RTMP URL: rtmp://a.rtmp.youtube.com/live2/$YOUTUBE_STREAM_KEY"
echo "   Local Web Interface: http://localhost:8001"
echo "   WebSocket: ws://localhost:8766"
echo "   Health Check: http://localhost:8081/health"
echo ""

# Start the headless server with YouTube streaming
echo "🚀 Starting headless emulator server with YouTube streaming..."
python3 server/local_server_headless_fixed.py

echo ""
echo "Server stopped."
