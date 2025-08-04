FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

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
    # Math tools for scaling calculations
    bc \
    # User management
    sudo \
    # Cleanup
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create proper user context (not root)
RUN useradd -m -s /bin/bash -u 1000 spectrum && \
    echo "spectrum ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set up Python environment
RUN pip3 install --no-cache-dir \
    websockets \
    aiohttp \
    boto3 \
    asyncio

# Create app directory with proper ownership
RUN mkdir -p /app /tmp/stream && \
    chown -R spectrum:spectrum /app /tmp/stream

# Create FUSE configuration directory
RUN mkdir -p /home/spectrum/.fuse && \
    chown -R spectrum:spectrum /home/spectrum/.fuse

# Copy the server code with OpenSE ROM configuration
COPY server/emulator_server_golden_reference_v2_final.py /app/emulator_server.py
COPY server/requirements.txt /app/requirements.txt

# Install Python requirements
RUN pip3 install --no-cache-dir -r /app/requirements.txt

# Fix ownership of app files
RUN chown -R spectrum:spectrum /app

# Environment variables for proper FUSE startup with OpenSE ROM
ENV DISPLAY=:99
ENV SDL_VIDEODRIVER=x11
ENV SDL_AUDIODRIVER=dummy
ENV SDL_JOYSTICK=0
ENV SDL_HAPTIC=0
ENV PULSE_RUNTIME_PATH=/tmp/pulse
ENV STREAM_BUCKET=spectrum-emulator-stream-dev-043309319786

# Video configuration
ENV VIRTUAL_DISPLAY_SIZE=800x600x24
ENV CAPTURE_SIZE=320x240
ENV CAPTURE_OFFSET_X=240
ENV CAPTURE_OFFSET_Y=180
ENV SCALE_FACTOR=1.8
ENV OUTPUT_RESOLUTION=1280x720
ENV FRAME_RATE=30

# YouTube streaming key
ENV YOUTUBE_STREAM_KEY=8w86-k4v4-4trq-pvwy-6v58

# Version information
ENV VERSION=1.0.0-opense-rom
ENV BUILD_TIME=2025-08-04T23:30:00Z

# Create startup script
RUN echo '#!/bin/bash\n\
echo "🏆 Starting ZX Spectrum Emulator Server with OpenSE ROM"\n\
echo "======================================================"\n\
echo "Version: $VERSION"\n\
echo "ROM: OpenSE (Open Source)"\n\
echo "User: $(whoami)"\n\
echo ""\n\
echo "🚀 Starting server with OpenSE ROM configuration..."\n\
exec python3 /app/emulator_server.py\n\
' > /app/start.sh && chmod +x /app/start.sh

# Fix ownership of startup script
RUN chown spectrum:spectrum /app/start.sh

# Switch to spectrum user
USER spectrum

# Set proper home directory
ENV HOME=/home/spectrum

# Expose ports
EXPOSE 8080 8765

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Set working directory
WORKDIR /app

# Start the server
CMD ["/app/start.sh"]
