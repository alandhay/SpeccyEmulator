#!/bin/bash

echo "Starting ZX Spectrum ULTRA HD Streaming Setup..."

# Set up Ultra HD environment
export DISPLAY=:99
export PULSE_RUNTIME_PATH=/tmp/pulse
export SDL_VIDEODRIVER=x11
export SDL_AUDIODRIVER=pulse

# Get resolution from environment or use Ultra HD default
DISPLAY_SIZE=${DISPLAY_SIZE:-"1920x1080"}
STREAM_RESOLUTION=${STREAM_RESOLUTION:-"1920x1080"}
STREAM_BITRATE=${STREAM_BITRATE:-"8000k"}

echo "Ultra HD Configuration:"
echo "  Display Size: $DISPLAY_SIZE"
echo "  Stream Resolution: $STREAM_RESOLUTION"
echo "  Stream Bitrate: $STREAM_BITRATE"

# Create necessary directories
mkdir -p /app/stream/hls /tmp/pulse

# Start virtual X11 display with Ultra HD resolution
echo "Starting virtual X11 display..."
Xvfb :99 -screen 0 ${DISPLAY_SIZE}x24 -ac +extension GLX &
XVFB_PID=$!

# Wait for X11 to be ready
sleep 5
echo "Testing X11 display..."
if xdpyinfo -display :99 >/dev/null 2>&1; then
    echo "X11 display is ready"
else
    echo "ERROR: X11 display failed to start"
    exit 1
fi

# Start PulseAudio
echo "Starting PulseAudio..."
pulseaudio --start --exit-idle-time=-1 &
PULSE_PID=$!

# Wait for PulseAudio to be ready
sleep 3
echo "Testing PulseAudio..."
if pulseaudio --check; then
    echo "PulseAudio is ready"
else
    echo "WARNING: PulseAudio may not be working properly"
fi

# Test SDL2 configuration with pygame
echo "Testing SDL2 configuration..."
echo "DISPLAY: $DISPLAY"
echo "SDL_VIDEODRIVER: $SDL_VIDEODRIVER"
echo "SDL_AUDIODRIVER: $SDL_AUDIODRIVER"

# Test pygame installation and SDL2 functionality
python3 -c "
import os
import sys
os.environ['SDL_VIDEODRIVER'] = 'x11'
os.environ['SDL_AUDIODRIVER'] = 'pulse'
try:
    import pygame
    print(f'pygame version: {pygame.version.ver}')
    pygame.init()
    # Test display creation
    screen = pygame.display.set_mode((256, 192))
    print('SDL2 display test: SUCCESS')
    pygame.quit()
    print('SDL2 test: SUCCESS')
except ImportError as e:
    print(f'pygame import failed: {e}')
    sys.exit(1)
except Exception as e:
    print(f'SDL2 test failed: {e}')
    sys.exit(1)
"

if [ $? -ne 0 ]; then
    echo "ERROR: SDL2/pygame test failed"
    exit 1
fi

# Start health check server
echo "Starting health check server..."
python3 -c "
import http.server
import socketserver
import threading
import time
import json

class HealthHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            health_data = {
                'status': 'healthy',
                'resolution': '$STREAM_RESOLUTION',
                'bitrate': '$STREAM_BITRATE',
                'timestamp': time.time()
            }
            self.wfile.write(json.dumps(health_data).encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        # Suppress access logs for health checks
        if '/health' not in format % args:
            super().log_message(format, *args)

def start_health_server():
    try:
        with socketserver.TCPServer(('', 8080), HealthHandler) as httpd:
            httpd.serve_forever()
    except Exception as e:
        print(f'Health server error: {e}')

# Start health server in background thread
health_thread = threading.Thread(target=start_health_server, daemon=True)
health_thread.start()

print('Health check server started on port 8080')
" &
HEALTH_PID=$!

# Wait for health server to start
sleep 2

# Start WebSocket server with Ultra HD configuration
echo "Starting WebSocket server..."
cd /app/server
python3 emulator_server_ultra_hd.py &
WEBSOCKET_PID=$!

# Function to cleanup on exit
cleanup() {
    echo "Cleaning up processes..."
    kill $XVFB_PID $PULSE_PID $HEALTH_PID $WEBSOCKET_PID 2>/dev/null
    # Kill any remaining FFmpeg processes
    pkill -f ffmpeg 2>/dev/null
    # Kill any remaining FUSE processes
    pkill -f fuse-sdl 2>/dev/null
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

# Function to restart PulseAudio if it dies
restart_pulseaudio() {
    if ! pulseaudio --check; then
        echo "PulseAudio died, restarting..."
        pulseaudio --kill 2>/dev/null
        sleep 1
        pulseaudio --start --exit-idle-time=-1 &
        PULSE_PID=$!
    fi
}

# Monitor and restart critical processes
echo "Ultra HD ZX Spectrum Emulator started successfully!"
echo "Monitoring processes..."

while true; do
    # Check if critical processes are still running
    if ! kill -0 $XVFB_PID 2>/dev/null; then
        echo "Xvfb died, restarting with Ultra HD resolution..."
        Xvfb :99 -screen 0 ${DISPLAY_SIZE}x24 -ac +extension GLX &
        XVFB_PID=$!
        sleep 3
    fi
    
    if ! kill -0 $WEBSOCKET_PID 2>/dev/null; then
        echo "WebSocket server died, restarting..."
        cd /app/server
        python3 emulator_server_ultra_hd.py &
        WEBSOCKET_PID=$!
    fi
    
    # Check PulseAudio periodically
    restart_pulseaudio
    
    sleep 10
done
