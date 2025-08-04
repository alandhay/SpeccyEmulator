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

# Copy the golden reference server code
COPY server/emulator_server_golden_reference.py /app/emulator_server.py
COPY server/requirements.txt /app/requirements.txt

# Install Python requirements
RUN pip3 install --no-cache-dir -r /app/requirements.txt

# Set up environment variables - FIXED to match working local strategy
ENV DISPLAY=:99
ENV SDL_VIDEODRIVER=x11
ENV SDL_AUDIODRIVER=pulse
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
ENV VERSION=1.0.0-golden-reference
ENV BUILD_TIME=2025-08-04T00:00:00Z

# Create startup script with golden reference configuration
RUN echo '#!/bin/bash\n\
echo "🏆 Starting Golden Reference ZX Spectrum Emulator Server"\n\
echo "========================================================"\n\
echo "Version: $VERSION"\n\
echo "Build Time: $BUILD_TIME"\n\
echo "Strategy: Proven local FUSE streaming approach"\n\
echo ""\n\
echo "🎯 Configuration:"\n\
echo "  Virtual Display: $VIRTUAL_DISPLAY_SIZE"\n\
echo "  Capture Size: $CAPTURE_SIZE"\n\
echo "  Capture Offset: +$CAPTURE_OFFSET_X,$CAPTURE_OFFSET_Y"\n\
echo "  Scale Factor: $SCALE_FACTOR"\n\
echo "  Output Resolution: $OUTPUT_RESOLUTION"\n\
echo "  Frame Rate: $FRAME_RATE FPS"\n\
echo "  Cursor: Hidden (-draw_mouse 0)"\n\
echo "  Audio: Synthetic (anullsrc)"\n\
echo ""\n\
echo "🚀 Starting server with golden reference strategy..."\n\
exec python3 /app/emulator_server.py\n\
' > /app/start.sh && chmod +x /app/start.sh

# Expose ports
EXPOSE 8080 8765

# Health check with longer grace period for golden reference
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Set working directory
WORKDIR /app

# Start the golden reference server
CMD ["/app/start.sh"]
