# Framebuffer-based ZX Spectrum Emulator
# Eliminates window positioning issues with direct framebuffer capture

FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install all required packages
RUN apt-get update && apt-get install -y \
    # Core emulator and display
    fuse-emulator-sdl \
    xvfb \
    x11-utils \
    xdotool \
    # Video and audio processing
    ffmpeg \
    pulseaudio \
    pulseaudio-utils \
    # Python and networking
    python3 \
    python3-pip \
    curl \
    # AWS tools
    awscli \
    # Framebuffer tools
    x11vnc \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip3 install \
    websockets \
    aiohttp \
    boto3 \
    asyncio

# Create application directory
WORKDIR /app

# Copy server files
COPY server/emulator_server_framebuffer.py /app/server.py
COPY server/requirements.txt /app/requirements.txt

# Create necessary directories
RUN mkdir -p /tmp/stream /tmp/pulse /app/logs

# Set environment variables for framebuffer mode
ENV DISPLAY=:99
ENV SDL_VIDEODRIVER=x11
ENV SDL_AUDIODRIVER=pulse
ENV PULSE_RUNTIME_PATH=/tmp/pulse

# Expose ports
EXPOSE 8080 8765

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Start the server
CMD ["python3", "/app/server.py"]
