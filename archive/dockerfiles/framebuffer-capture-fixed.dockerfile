FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install dependencies
RUN apt-get update && apt-get install -y \
    fuse-emulator-sdl \
    ffmpeg \
    python3 \
    python3-pip \
    xvfb \
    pulseaudio \
    x11-utils \
    awscli \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip3 install websockets aiohttp boto3

# Copy fixed server
COPY server/emulator_server_framebuffer_fixed.py /app/server.py

# Make executable
RUN chmod +x /app/server.py

# Set environment variables
ENV DISPLAY=:99
ENV SDL_VIDEODRIVER=x11
ENV SDL_AUDIODRIVER=pulse
ENV PULSE_RUNTIME_PATH=/tmp/pulse
ENV VERSION=1.0.0-framebuffer-capture-fixed
ENV BUILD_TIME=2025-08-03T08:30:00Z

# Expose ports
EXPOSE 8080 8765

# Start server
CMD ["/app/server.py"]
