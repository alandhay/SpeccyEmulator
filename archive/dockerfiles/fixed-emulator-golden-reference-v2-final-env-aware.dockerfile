FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    fuse-emulator-sdl \
    ffmpeg \
    python3 \
    python3-pip \
    xvfb \
    pulseaudio \
    x11-utils \
    xdotool \
    awscli \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create spectrum user and home directory
RUN useradd -m -s /bin/bash spectrum && \
    mkdir -p /home/spectrum/.fuse && \
    chown -R spectrum:spectrum /home/spectrum

# Set up working directory
WORKDIR /app

# Copy Python requirements and install
COPY server/requirements.txt /app/
RUN pip3 install -r requirements.txt

# Install additional Python packages for environment detection
RUN pip3 install requests boto3

# Copy the environment-aware server
COPY server/emulator_server_golden_reference_v2_final_env_aware.py /app/server.py

# Create startup script
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
echo "🏆 Starting Golden Reference ZX Spectrum Emulator Server v2 FINAL (Environment Aware)"\n\
echo "================================================================"\n\
echo "Version: 1.0.0-golden-reference-v2-final-env-aware"\n\
echo "Build Time: 2025-08-04T22:15:00Z"\n\
echo "User: spectrum"\n\
echo "Home: /home/spectrum"\n\
echo "Strategy: FINAL - Proven local test configuration + Environment Detection"\n\
echo ""\n\
echo "🎯 Configuration (with dynamic positioning):"\n\
echo "  Virtual Display: 800x600x24"\n\
echo "  Capture Size: 320x240"\n\
echo "  Capture Offset: Dynamic (detects FUSE window position)"\n\
echo "  Scale Factor: 1.8 (90% of 2x)"\n\
echo "  Output Resolution: 1280x720"\n\
echo "  Frame Rate: 30 FPS"\n\
echo "  SDL Video Driver: x11"\n\
echo "  SDL Audio Driver: dummy"\n\
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
echo "  ✅ Environment Detection: Auto-detects AWS vs Local"\n\
echo ""\n\
echo "🚀 Starting server with FINAL proven configuration..."\n\
\n\
# Switch to spectrum user and start server\n\
exec su - spectrum -c "cd /app && python3 server.py"\n\
' > /app/start.sh && chmod +x /app/start.sh

# Switch to spectrum user
USER spectrum

# Set environment variables
ENV HOME=/home/spectrum
ENV USER=spectrum
ENV DISPLAY=:99
ENV SDL_VIDEODRIVER=x11
ENV SDL_AUDIODRIVER=dummy
ENV PULSE_RUNTIME_PATH=/tmp/pulse

# Default environment variables (can be overridden)
ENV YOUTUBE_STREAM_KEY=8w86-k4v4-4trq-pvwy-6v58
ENV STREAM_BUCKET=spectrum-emulator-stream-dev-043309319786

# Expose ports
EXPOSE 8080 8765

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Start the server
CMD ["/app/start.sh"]
