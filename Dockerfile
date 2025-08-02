FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:99

# Install all required packages in one layer
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    curl \
    xvfb \
    fuse-emulator-sdl \
    ffmpeg \
    pulseaudio \
    x11-utils \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages
RUN pip3 install websockets aiohttp

# Create stream directory
RUN mkdir -p /tmp/stream

# Copy the application code
COPY server/emulator_server.py /app/emulator_server.py

# Create startup script
RUN echo '#!/bin/bash\n\
set -e\n\
echo "Starting ZX Spectrum Emulator with centered video capture..."\n\
\n\
# Start virtual display\n\
Xvfb :99 -screen 0 512x384x24 &\n\
sleep 3\n\
\n\
# Start PulseAudio\n\
pulseaudio --start --exit-idle-time=-1 &\n\
\n\
# Start the Python server\n\
cd /app\n\
python3 emulator_server.py\n\
' > /app/start.sh && chmod +x /app/start.sh

WORKDIR /app

# Expose ports
EXPOSE 8080 8765

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Start the application
CMD ["/app/start.sh"]
