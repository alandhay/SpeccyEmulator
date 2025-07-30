# ZX Spectrum Emulator Docker Image
FROM ubuntu:22.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    fuse-emulator-sdl \
    fuse-emulator-common \
    ffmpeg \
    imagemagick \
    x11-utils \
    xvfb \
    curl \
    wget \
    lsof \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy requirements first for better caching
COPY server/requirements.txt ./server/
COPY requirements-docker.txt ./

# Create virtual environment and install Python dependencies
RUN python3 -m venv venv && \
    . venv/bin/activate && \
    pip install --upgrade pip && \
    pip install -r server/requirements.txt && \
    pip install -r requirements-docker.txt

# Copy application code
COPY server/ ./server/
COPY games/ ./games/
COPY scripts/ ./scripts/

# Create necessary directories
RUN mkdir -p logs stream/hls

# Set up X11 virtual display
ENV DISPLAY=:99

# Create startup script
RUN cat > start-services.sh << 'EOF'
#!/bin/bash
set -e

# Start virtual display
Xvfb :99 -screen 0 1024x768x24 &
XVFB_PID=$!
echo "Started Xvfb (PID: $XVFB_PID)"

# Wait for X11 to be ready
sleep 2

# Activate virtual environment
source venv/bin/activate

# Start the emulator server
echo "Starting emulator server..."
python3 server/emulator_server.py &
SERVER_PID=$!
echo "Started emulator server (PID: $SERVER_PID)"

# Function to cleanup on exit
cleanup() {
    echo "Shutting down services..."
    kill $SERVER_PID 2>/dev/null || true
    kill $XVFB_PID 2>/dev/null || true
    pkill -f "fuse" 2>/dev/null || true
    pkill -f "ffmpeg.*x11grab" 2>/dev/null || true
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Wait for services
wait $SERVER_PID
EOF

RUN chmod +x start-services.sh

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8765/health || exit 1

# Expose ports
EXPOSE 8765 8080

# Start services
CMD ["./start-services.sh"]
