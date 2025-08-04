#!/bin/bash

echo "🧪 ZX Spectrum Emulator Local Test Setup"
echo "========================================"

# Check if we have the required dependencies
echo "📋 Checking dependencies..."

# Check for Python packages
python3 -c "import websockets, aiohttp, asyncio" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ Python packages available"
else
    echo "❌ Missing Python packages. Installing..."
    pip3 install websockets aiohttp asyncio
fi

# Check for xdotool (needed for key forwarding)
if command -v xdotool &> /dev/null; then
    echo "✅ xdotool available"
else
    echo "❌ xdotool not found. Installing..."
    sudo apt-get update && sudo apt-get install -y xdotool
fi

# Check for Xvfb (virtual display)
if command -v Xvfb &> /dev/null; then
    echo "✅ Xvfb available"
else
    echo "❌ Xvfb not found. Installing..."
    sudo apt-get install -y xvfb
fi

# Check for FUSE emulator
if command -v fuse-sdl &> /dev/null; then
    echo "✅ FUSE emulator available"
else
    echo "❌ FUSE emulator not found. Installing..."
    sudo apt-get install -y fuse-emulator-sdl
fi

echo ""
echo "🚀 Starting local test server..."
echo "Press Ctrl+C to stop the server"
echo ""

# Set environment variables for local testing
export DISPLAY=:99
export SDL_VIDEODRIVER=x11
export SDL_AUDIODRIVER=pulse
export PULSE_RUNTIME_PATH=/tmp/pulse
export STREAM_BUCKET=test-bucket

# Run the server
cd /home/ubuntu/workspace/SpeccyEmulator
python3 server/emulator_server_fixed_v5.py
