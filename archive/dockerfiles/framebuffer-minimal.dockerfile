# Minimal framebuffer fix - extends existing working image
FROM 043309319786.dkr.ecr.us-east-1.amazonaws.com/spectrum-emulator:ffmpeg-fix

# Copy the fixed framebuffer server
COPY server/emulator_server_framebuffer.py /app/server.py

# Set framebuffer environment variables
ENV FRAMEBUFFER_MODE=true
ENV VERSION=1.0.0-framebuffer-fixed
ENV BUILD_TIME=2025-08-03T08:15:00Z

# Keep the same startup command
CMD ["python3", "/app/server.py"]
