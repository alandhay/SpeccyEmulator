FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install all required packages in a single layer
RUN apt-get update && apt-get install -y \
    # Core system packages
    curl wget ca-certificates gnupg lsb-release \
    # X11 and graphics
    xvfb x11-utils x11-xserver-utils \
    # Audio
    pulseaudio pulseaudio-utils \
    # Video processing
    ffmpeg \
    # ZX Spectrum emulator
    fuse-emulator-sdl fuse-emulator-common \
    # Python and development
    python3 python3-pip python3-dev \
    # AWS CLI
    awscli \
    # Cleanup
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip3 install --no-cache-dir \
    websockets \
    aiohttp \
    asyncio \
    boto3

# Create application directory
WORKDIR /app

# Copy the corrected server script
COPY fix-emulator-integration-corrected.py /app/server.py

# Make script executable
RUN chmod +x /app/server.py

# Create required directories
RUN mkdir -p /tmp/stream /tmp/pulse

# Set environment variables
ENV DISPLAY=:99
ENV SDL_VIDEODRIVER=x11
ENV SDL_AUDIODRIVER=pulse
ENV PULSE_RUNTIME_PATH=/tmp/pulse

# Expose ports
EXPOSE 8080 8765

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Start the corrected server
CMD ["python3", "/app/server.py"]
