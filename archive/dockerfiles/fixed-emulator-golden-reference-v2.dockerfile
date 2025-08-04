FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install system dependencies - matching proven local setup
RUN apt-get update && apt-get install -y \
    # Core system tools
    curl wget git vim nano \
    # X11 and display (matching local test environment)
    xvfb x11-utils x11-apps xdotool \
    # Audio (keeping PulseAudio for container compatibility)
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

# CRITICAL FIX: Create proper user context (not root)
RUN useradd -m -s /bin/bash -u 1000 spectrum && \
    echo "spectrum ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# CRITICAL FIX: Create necessary device nodes for container
RUN mknod /dev/null c 1 3 2>/dev/null || true && \
    mknod /dev/zero c 1 5 2>/dev/null || true && \
    chmod 666 /dev/null /dev/zero 2>/dev/null || true

# Set up Python environment
RUN pip3 install --no-cache-dir \
    websockets \
    aiohttp \
    boto3 \
    asyncio

# Create app directory with proper ownership
RUN mkdir -p /app /tmp/stream && \
    chown -R spectrum:spectrum /app /tmp/stream

# CRITICAL FIX: Create FUSE configuration directory
RUN mkdir -p /home/spectrum/.fuse && \
    chown -R spectrum:spectrum /home/spectrum/.fuse

# Copy the golden reference server code
COPY server/emulator_server_golden_reference_v2.py /app/emulator_server.py
COPY server/requirements.txt /app/requirements.txt

# Install Python requirements
RUN pip3 install --no-cache-dir -r /app/requirements.txt

# Fix ownership of app files
RUN chown -R spectrum:spectrum /app

# CRITICAL FIX: Set up environment variables for proper FUSE startup
ENV DISPLAY=:99
ENV SDL_VIDEODRIVER=x11
ENV SDL_AUDIODRIVER=dummy
ENV SDL_JOYSTICK=0
ENV SDL_HAPTIC=0
ENV PULSE_RUNTIME_PATH=/tmp/pulse
ENV STREAM_BUCKET=spectrum-emulator-stream-dev-043309319786

# GOLDEN REFERENCE: Video configuration matching proven local setup
ENV VIRTUAL_DISPLAY_SIZE=800x600x24
ENV CAPTURE_SIZE=320x240
ENV CAPTURE_OFFSET_X=240
ENV CAPTURE_OFFSET_Y=180
ENV SCALE_FACTOR=1.8
ENV OUTPUT_RESOLUTION=1280x720
ENV FRAME_RATE=30

# Version information
ENV VERSION=1.0.0-golden-reference-v2
ENV BUILD_TIME=2025-08-04T01:00:00Z
ENV DEPLOYMENT_STATUS=production-ready
ENV LAST_UPDATED=2025-08-04T01:00:00Z

# Create startup script with user context fixes
RUN echo '#!/bin/bash\n\
echo "🏆 Starting Golden Reference ZX Spectrum Emulator Server v2"\n\
echo "============================================================"\n\
echo "Version: $VERSION"\n\
echo "Build Time: $BUILD_TIME"\n\
echo "Deployment Status: $DEPLOYMENT_STATUS"\n\
echo "Last Updated: $LAST_UPDATED"\n\
echo "User: $(whoami)"\n\
echo "Home: $HOME"\n\
echo "Strategy: Fixed user context + proven local FUSE streaming"\n\
echo ""\n\
echo "🎯 Configuration:"\n\
echo "  Virtual Display: $VIRTUAL_DISPLAY_SIZE"\n\
echo "  Capture Size: $CAPTURE_SIZE"\n\
echo "  Capture Offset: +$CAPTURE_OFFSET_X,$CAPTURE_OFFSET_Y"\n\
echo "  Scale Factor: $SCALE_FACTOR"\n\
echo "  Output Resolution: $OUTPUT_RESOLUTION"\n\
echo "  Frame Rate: $FRAME_RATE FPS"\n\
echo "  SDL Video Driver: $SDL_VIDEODRIVER"\n\
echo "  SDL Audio Driver: $SDL_AUDIODRIVER"\n\
echo ""\n\
echo "🔧 User Context Fixes:"\n\
echo "  Running as: $(whoami)"\n\
echo "  Home directory: $HOME"\n\
echo "  FUSE config dir: $HOME/.fuse"\n\
echo ""\n\
echo "🚀 Starting server with fixed user context..."\n\
exec python3 /app/emulator_server.py\n\
' > /app/start.sh && chmod +x /app/start.sh

# Fix ownership of startup script
RUN chown spectrum:spectrum /app/start.sh

# CRITICAL FIX: Switch to spectrum user (not root)
USER spectrum

# Set proper home directory
ENV HOME=/home/spectrum

# Expose ports
EXPOSE 8080 8765

# Health check with longer grace period for golden reference
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Set working directory
WORKDIR /app

# Start the golden reference server as spectrum user
CMD ["/app/start.sh"]
