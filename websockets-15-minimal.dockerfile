FROM 043309319786.dkr.ecr.us-east-1.amazonaws.com/spectrum-emulator:websockets-15-fixed

# Copy the corrected server file to overwrite the existing one
COPY server/emulator_server_websockets_15_fixed.py /app/server.py

# Update version to indicate this is the corrected version
ENV VERSION=1.0.0-websockets-15-corrected
ENV BUILD_TIME=2025-08-03T12:35:00Z

# Ensure it's executable
RUN chmod +x /app/server.py
