#!/bin/bash

echo "Starting Interactive ZX Spectrum Emulator Server..."

# Start virtual X11 display
echo "Starting virtual X11 display..."
Xvfb :99 -screen 0 1024x768x24 &
sleep 5

# Test X11 display
echo "Testing X11 display..."
DISPLAY=:99 xdpyinfo > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "X11 display is ready"
else
    echo "X11 display failed to start"
    exit 1
fi

# Start PulseAudio
echo "Starting PulseAudio..."
pulseaudio --start --exit-idle-time=-1 --system=false --disallow-exit &
sleep 3

# Test PulseAudio
echo "Testing PulseAudio..."
PULSE_RUNTIME_PATH=/tmp/pulse pulseaudio --check
if [ $? -eq 0 ]; then
    echo "PulseAudio is ready"
else
    echo "PulseAudio failed to start, continuing anyway..."
fi

# Set up environment
export DISPLAY=:99
export SDL_VIDEODRIVER=x11
export SDL_AUDIODRIVER=pulse
export PULSE_RUNTIME_PATH=/tmp/pulse

# Test SDL2 configuration
echo "Testing SDL2 configuration..."
echo "DISPLAY: $DISPLAY"
echo "SDL_VIDEODRIVER: $SDL_VIDEODRIVER"
echo "SDL_AUDIODRIVER: $SDL_AUDIODRIVER"

# Start the interactive emulator server
echo "Starting Interactive WebSocket server..."
echo "Server will be available on:"
echo "  WebSocket: ws://localhost:8765"
echo "  Health Check: http://localhost:8080/health"
echo "  Features: Interactive keyboard, real-time input, dual streaming"

exec python3 /app/emulator_server.py
