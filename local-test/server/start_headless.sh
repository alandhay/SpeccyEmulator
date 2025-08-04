#!/bin/bash

# Headless Local ZX Spectrum Emulator Server Startup Script
# =========================================================

set -e

echo "🚀 Starting Headless Local ZX Spectrum Emulator Server"
echo "======================================================"

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

echo "📁 Base directory: $BASE_DIR"
echo "📁 Script directory: $SCRIPT_DIR"

# Check if we're in the right directory
if [ ! -f "$SCRIPT_DIR/local_server_headless.py" ]; then
    echo "❌ Error: local_server_headless.py not found in $SCRIPT_DIR"
    exit 1
fi

# Check Python version
echo "🐍 Checking Python version..."
python3 --version

# Check if virtual environment exists, create if not
VENV_DIR="$BASE_DIR/venv"
if [ ! -d "$VENV_DIR" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
fi

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source "$VENV_DIR/bin/activate"

# Install/upgrade requirements
echo "📦 Installing requirements..."
pip install -r "$SCRIPT_DIR/requirements.txt"

# Check required system dependencies
echo "🔍 Checking system dependencies..."
MISSING_DEPS=()

for dep in fuse-sdl ffmpeg xdotool Xvfb pulseaudio; do
    if ! command -v "$dep" &> /dev/null; then
        MISSING_DEPS+=("$dep")
    else
        echo "✅ $dep is available"
    fi
done

if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
    echo "❌ Missing system dependencies: ${MISSING_DEPS[*]}"
    echo "Please install them with:"
    echo "sudo apt-get update"
    echo "sudo apt-get install -y fuse-emulator-sdl ffmpeg xdotool xvfb pulseaudio"
    exit 1
fi

# Set YouTube stream key if provided
if [ -n "$YOUTUBE_STREAM_KEY" ]; then
    echo "📺 YouTube stream key provided"
    export YOUTUBE_STREAM_KEY
else
    echo "ℹ️  No YouTube stream key provided (YouTube streaming will be disabled)"
fi

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p "$BASE_DIR/stream/hls"
mkdir -p "$BASE_DIR/logs"

# Clean up any existing stream files
echo "🧹 Cleaning up old stream files..."
rm -f "$BASE_DIR/stream/hls/"*.ts
rm -f "$BASE_DIR/stream/hls/"*.m3u8

# Clean up any existing X11 processes
echo "🧹 Cleaning up existing processes..."
pkill -f "Xvfb :99" || true
pkill -f "fuse-sdl" || true
pkill -f "ffmpeg.*x11grab" || true

# Set up signal handling for clean shutdown
cleanup() {
    echo ""
    echo "🛑 Shutting down server..."
    # Kill any background processes
    pkill -f "Xvfb :99" || true
    pkill -f "fuse-sdl" || true
    pkill -f "ffmpeg.*x11grab" || true
    pkill -f "pulseaudio" || true
    jobs -p | xargs -r kill
    exit 0
}

trap cleanup SIGINT SIGTERM

# Start the server
echo ""
echo "🎮 Starting Headless Local ZX Spectrum Emulator Server..."
echo "========================================================"
echo "📺 Web interface will be available at: http://localhost:8000"
echo "🔌 WebSocket server will be available at: ws://localhost:8765"
echo "❤️  Health check will be available at: http://localhost:8080/health"
echo "🖥️  Using virtual display :99 (headless mode)"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

cd "$SCRIPT_DIR"
python3 local_server_headless.py
