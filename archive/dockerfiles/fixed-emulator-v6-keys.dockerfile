FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Set timezone to prevent tzdata prompts
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install all required packages including xdotool (CRITICAL)
RUN apt-get update && apt-get install -y \
    fuse-emulator-sdl \
    ffmpeg \
    python3 \
    python3-pip \
    python3-websockets \
    python3-aiohttp \
    xvfb \
    pulseaudio \
    x11-utils \
    xdotool \
    awscli \
    && rm -rf /var/lib/apt/lists/*

# Create application directory
WORKDIR /app

# Copy server code
COPY server/emulator_server_fixed_v6.py /app/server.py
COPY server/requirements.txt /app/requirements.txt

# Install Python dependencies
RUN pip3 install -r requirements.txt

# Set environment variables
ENV DISPLAY=:99
ENV SDL_VIDEODRIVER=x11
ENV SDL_AUDIODRIVER=pulse
ENV PULSE_RUNTIME_PATH=/tmp/pulse

# Expose ports
EXPOSE 8765 8080

# Start script
CMD ["python3", "/app/server.py"]
