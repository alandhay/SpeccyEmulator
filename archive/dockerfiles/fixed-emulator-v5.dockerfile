FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # Core system tools
    curl wget git vim nano \
    # X11 and display
    xvfb x11-utils x11-apps xdotool \
    # Audio
    pulseaudio pulseaudio-utils \
    # Video processing
    ffmpeg \
    # ZX Spectrum emulator
    fuse-emulator-sdl \
    # Python and pip
    python3 python3-pip \
    # AWS CLI
    awscli \
    # Fonts for text overlays
    fonts-dejavu-core \
    # Cleanup
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set up Python environment
RUN pip3 install --no-cache-dir \
    websockets \
    aiohttp \
    boto3 \
    asyncio

# Create app directory
RUN mkdir -p /app /tmp/stream

# Copy the enhanced server code with real-time feedback
COPY server/emulator_server_fixed_v5.py /app/emulator_server.py
COPY server/requirements.txt /app/requirements.txt

# Install Python requirements
RUN pip3 install --no-cache-dir -r /app/requirements.txt

# Set up environment variables
ENV DISPLAY=:99
ENV SDL_VIDEODRIVER=x11
ENV SDL_AUDIODRIVER=pulse
ENV PULSE_RUNTIME_PATH=/tmp/pulse
ENV STREAM_BUCKET=spectrum-emulator-stream-dev-043309319786
# Video scaling configuration
ENV CAPTURE_SIZE=256x192
ENV DISPLAY_SIZE=256x192
ENV CAPTURE_OFFSET=0,0
ENV SCALE_FACTOR=2

# Create startup script
RUN echo '#!/bin/bash\n\
echo "Starting Enhanced ZX Spectrum Emulator Server v7..."\n\
echo "Version: 1.0.0-v7-complete"\n\
echo "Features: Video scaling, YouTube streaming, Mouse support, Cursor hiding, Virtual keyboard fixes"\n\
echo ""\n\
echo "Environment:"\n\
echo "  DISPLAY: $DISPLAY"\n\
echo "  SDL_VIDEODRIVER: $SDL_VIDEODRIVER"\n\
echo "  SDL_AUDIODRIVER: $SDL_AUDIODRIVER"\n\
echo "  STREAM_BUCKET: $STREAM_BUCKET"\n\
echo "  CAPTURE_SIZE: $CAPTURE_SIZE"\n\
echo "  DISPLAY_SIZE: $DISPLAY_SIZE"\n\
echo "  SCALE_FACTOR: $SCALE_FACTOR"\n\
echo ""\n\
echo "Starting server..."\n\
exec python3 /app/emulator_server.py\n\
' > /app/start.sh && chmod +x /app/start.sh

# Expose ports
EXPOSE 8080 8765

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Set working directory
WORKDIR /app

# Start the server
CMD ["/app/start.sh"]
