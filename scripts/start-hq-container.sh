#!/bin/bash

echo "Starting ZX Spectrum HIGH QUALITY Streaming Setup..."

# Set up environment for high quality streaming
export DISPLAY=:99
export PULSE_RUNTIME_PATH=/tmp/pulse
export SDL_VIDEODRIVER=x11
export SDL_AUDIODRIVER=pulse

# Create necessary directories
mkdir -p /app/stream/hls /tmp/pulse

# Start virtual display with higher resolution for better quality
echo "Starting HIGH QUALITY virtual X11 display..."
Xvfb :99 -screen 0 1024x768x24 &
XVFB_PID=$!

# Wait for X11 to be ready
sleep 3

# Start PulseAudio with high quality settings
echo "Starting PulseAudio with HIGH QUALITY settings..."
pulseaudio --start --exit-idle-time=-1 &
PULSE_PID=$!

# Wait for PulseAudio to be ready
sleep 2

# Start health check endpoint in background
echo "Starting HIGH QUALITY health check server..."
python3 -c "
import http.server
import socketserver
import threading
import time
import os

class HealthHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            
            # Include quality information in health check
            output_res = os.getenv('OUTPUT_RESOLUTION', '1920x1080')
            video_bitrate = os.getenv('VIDEO_BITRATE', '5000k')
            youtube_bitrate = os.getenv('YOUTUBE_BITRATE', '6000k')
            
            health_info = f'HIGH QUALITY OK - {output_res} @ HLS:{video_bitrate} YouTube:{youtube_bitrate}'
            self.wfile.write(health_info.encode())
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

print('HIGH QUALITY health check server started on port 8080')
" &
HEALTH_PID=$!

# Wait for health server to start
sleep 2

# Start HIGH QUALITY WebSocket server
echo "Starting HIGH QUALITY WebSocket server..."
cd /app/server
python3 emulator_server.py &
WEBSOCKET_PID=$!

# Function to cleanup on exit
cleanup() {
    echo "Cleaning up HIGH QUALITY processes..."
    kill $XVFB_PID $PULSE_PID $HEALTH_PID $WEBSOCKET_PID 2>/dev/null
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

# Wait for any process to exit and restart if needed
while true; do
    # Check if critical processes are still running
    if ! kill -0 $XVFB_PID 2>/dev/null; then
        echo "Xvfb died, restarting with HIGH QUALITY settings..."
        Xvfb :99 -screen 0 1024x768x24 &
        XVFB_PID=$!
    fi
    
    if ! kill -0 $WEBSOCKET_PID 2>/dev/null; then
        echo "HIGH QUALITY WebSocket server died, restarting..."
        cd /app/server
        python3 emulator_server.py &
        WEBSOCKET_PID=$!
    fi
    
    sleep 10
done
