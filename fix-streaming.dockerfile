# Fix for HLS segment naming mismatch
# This Dockerfile creates a corrected version that uses consistent naming
FROM 043309319786.dkr.ecr.us-east-1.amazonaws.com/spectrum-emulator:scaling-fixed

# Copy a fixed version of the emulator server that uses correct segment naming
COPY fix-segment-naming.py /app/emulator_server.py
