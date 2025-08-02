#!/bin/bash

echo "Starting ZX Spectrum DUAL OUTPUT Streaming Setup..."

# Set up environment with proper SDL2 configuration
export DISPLAY=:99
export PULSE_RUNTIME_PATH=/tmp/pulse
export SDL_VIDEODRIVER=x11
export SDL_AUDIODRIVER=pulse
export XAUTHORITY=/tmp/.Xauth

# Create necessary directories
mkdir -p /app/stream/hls /tmp/pulse

# Create X11 authority file
touch /tmp/.Xauth

# Start virtual display with proper configuration for SDL2
echo "Starting virtual X11 display..."
Xvfb :99 -screen 0 512x384x24 -ac -nolisten tcp -dpi 96 &
XVFB_PID=$!

# Wait for X11 to be ready
sleep 5

# Test X11 display
echo "Testing X11 display..."
DISPLAY=:99 xdpyinfo >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "X11 display is ready"
else
    echo "WARNING: X11 display test failed"
fi

# Start PulseAudio with proper configuration
echo "Starting PulseAudio..."
pulseaudio --start --exit-idle-time=-1 --disable-shm &
PULSE_PID=$!

# Wait for PulseAudio to be ready
sleep 3

# Test PulseAudio
echo "Testing PulseAudio..."
pulseaudio --check
if [ $? -eq 0 ]; then
    echo "PulseAudio is ready"
else
    echo "WARNING: PulseAudio test failed"
fi

# Test SDL2 configuration
echo "Testing SDL2 configuration..."
python3 -c "
import os
import subprocess
print(f'DISPLAY: {os.environ.get(\"DISPLAY\")}')
print(f'SDL_VIDEODRIVER: {os.environ.get(\"SDL_VIDEODRIVER\")}')
print(f'SDL_AUDIODRIVER: {os.environ.get(\"SDL_AUDIODRIVER\")}')

# Test if we can create a simple SDL window
try:
    result = subprocess.run(['python3', '-c', '''
import os
os.environ[\"SDL_VIDEODRIVER\"] = \"x11\"
try:
    import pygame
    pygame.init()
    screen = pygame.display.set_mode((256, 192))
    pygame.quit()
    print(\"SDL2 test: SUCCESS\")
except Exception as e:
    print(f\"SDL2 test failed: {e}\")
'''], capture_output=True, text=True, timeout=10)
    print(result.stdout)
    if result.stderr:
        print(f'SDL2 stderr: {result.stderr}')
except Exception as e:
    print(f'SDL2 test error: {e}')
"

# Start health check endpoint in background
echo "Starting health check server..."
python3 -c "
import http.server
import socketserver
import threading
import time

class HealthHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'OK - X11 and PulseAudio ready')
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        # Suppress access logs
        pass

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

# Start WebSocket server
echo "Starting WebSocket server..."
cd /app/server
python3 emulator_server.py &
WEBSOCKET_PID=$!

# Function to cleanup on exit
cleanup() {
    echo "Cleaning up processes..."
    kill $XVFB_PID $PULSE_PID $HEALTH_PID $WEBSOCKET_PID 2>/dev/null
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

# Wait for any process to exit and restart if needed
while true; do
    # Check if critical processes are still running
    if ! kill -0 $XVFB_PID 2>/dev/null; then
        echo "Xvfb died, restarting..."
        Xvfb :99 -screen 0 512x384x24 -ac -nolisten tcp -dpi 96 &
        XVFB_PID=$!
        sleep 3
    fi
    
    if ! kill -0 $PULSE_PID 2>/dev/null; then
        echo "PulseAudio died, restarting..."
        pulseaudio --start --exit-idle-time=-1 --disable-shm &
        PULSE_PID=$!
        sleep 2
    fi
    
    if ! kill -0 $WEBSOCKET_PID 2>/dev/null; then
        echo "WebSocket server died, restarting..."
        cd /app/server
        python3 emulator_server.py &
        WEBSOCKET_PID=$!
    fi
    
    sleep 10
done
