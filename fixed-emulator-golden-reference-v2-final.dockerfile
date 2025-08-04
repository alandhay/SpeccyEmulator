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

# Copy the FINAL golden reference server code
COPY server/emulator_server_golden_reference_v2_final.py /app/emulator_server.py
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

# FINAL: Video configuration matching PROVEN local setup
ENV VIRTUAL_DISPLAY_SIZE=800x600x24
ENV CAPTURE_SIZE=320x240
ENV CAPTURE_OFFSET_X=240
ENV CAPTURE_OFFSET_Y=180
ENV SCALE_FACTOR=1.8
ENV OUTPUT_RESOLUTION=1280x720
ENV FRAME_RATE=30

# FINAL: YouTube streaming key from proven local test
ENV YOUTUBE_STREAM_KEY=8w86-k4v4-4trq-pvwy-6v58

# Version information
ENV VERSION=1.0.0-golden-reference-v2-final
ENV BUILD_TIME=2025-08-04T20:35:00Z

# Create startup script with user context fixes
RUN echo '#!/bin/bash\n\
echo "🏆 Starting Golden Reference ZX Spectrum Emulator Server v2 FINAL"\n\
echo "================================================================"\n\
echo "Version: $VERSION"\n\
echo "Build Time: $BUILD_TIME"\n\
echo "User: $(whoami)"\n\
echo "Home: $HOME"\n\
echo "Strategy: FINAL - Proven local test configuration + No cursor + 1.8x scaling"\n\
echo ""\n\
echo "🎯 Configuration (with dynamic positioning):"\n\
echo "  Virtual Display: $VIRTUAL_DISPLAY_SIZE"\n\
echo "  Capture Size: $CAPTURE_SIZE"\n\
echo "  Capture Offset: Dynamic (detects FUSE window position)"\n\
echo "  Scale Factor: $SCALE_FACTOR (90% of 2x)"\n\
echo "  Output Resolution: $OUTPUT_RESOLUTION"\n\
echo "  Frame Rate: $FRAME_RATE FPS"\n\
echo "  SDL Video Driver: $SDL_VIDEODRIVER"\n\
echo "  SDL Audio Driver: $SDL_AUDIODRIVER"\n\
echo "  YouTube Stream Key: ${YOUTUBE_STREAM_KEY:0:8}..."\n\
echo ""\n\
echo "🔧 FINAL Fixes Applied:"\n\
echo "  ✅ User Context: Running as spectrum user"\n\
echo "  ✅ FUSE Startup: No more splash screen hang"\n\
echo "  ✅ FFmpeg No Cursor: -draw_mouse 0 applied"\n\
echo "  ✅ Scaling: 1.8x (90% of 2x) for perfect size"\n\
echo "  ✅ Home Directory: Proper /home/spectrum setup"\n\
echo "  ✅ FUSE Config: Created .fuse configuration directory"\n\
echo "  ✅ YouTube Key: Using proven working stream key"\n\
echo "  ✅ IPv4 Network Fix: Direct IP for ECS compatibility"\n\
echo "  ✅ Dynamic Positioning: Auto-detects FUSE window location"\n\
echo ""\n\
echo "🚀 Starting server with FINAL proven configuration..."\n\
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

# Start the FINAL golden reference server as spectrum user
CMD ["/app/start.sh"]
