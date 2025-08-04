#!/bin/bash

# Quick Start Script for Local Testing
# ====================================

echo "🚀 Starting Local ZX Spectrum Emulator Test Environment"
echo "======================================================="

cd "$(dirname "$0")"

# Clean up any existing processes
echo "🧹 Cleaning up existing processes..."
pkill -f "Xvfb :99" || true
pkill -f "fuse-sdl" || true
pkill -f "ffmpeg.*x11grab" || true

# Start the headless server
echo "🎮 Starting headless server..."
python3 server/local_server_headless_fixed.py
