#!/bin/bash

# DIAGNOSTIC TOOL: Analyze FUSE Window Size and Position
# ======================================================
# This script helps diagnose why scaling isn't working by showing:
# - Virtual display size
# - FUSE window actual size and position
# - What FFmpeg is actually capturing
# - Recommendations for proper scaling

echo "🔍 FUSE Window Diagnostic Tool"
echo "=============================="

# Start virtual display
echo "Starting diagnostic virtual display..."
export DISPLAY=:96
Xvfb :96 -screen 0 800x600x24 -ac &
XVFB_PID=$!
sleep 3

echo "✅ Virtual display :96 started (800x600x24)"

# Start FUSE
echo "Starting FUSE for analysis..."
fuse-sdl --machine 48 --no-sound &
FUSE_PID=$!
sleep 5

echo "✅ FUSE started"
echo ""

# Install xwininfo if not available
if ! command -v xwininfo &> /dev/null; then
    echo "Installing xwininfo for window analysis..."
    sudo apt-get update -qq && sudo apt-get install -y x11-utils
fi

# Analyze the display and windows
echo "📊 DISPLAY ANALYSIS"
echo "==================="
echo "Virtual Display: 800x600x24 on :96"
echo ""

echo "📋 WINDOW LIST"
echo "=============="
echo "All windows on display :96:"
xwininfo -root -tree -display :96 | grep -E "(fuse|FUSE|spectrum|Spectrum)" || echo "No FUSE windows found with standard names"
echo ""

echo "🎯 FUSE WINDOW DETAILS"
echo "======================"
echo "Attempting to find FUSE window..."

# Try to find FUSE window by different methods
FUSE_WINDOW=$(xwininfo -root -tree -display :96 | grep -i fuse | head -1 | awk '{print $1}' | sed 's/://g')

if [ -n "$FUSE_WINDOW" ]; then
    echo "Found FUSE window ID: $FUSE_WINDOW"
    echo ""
    echo "FUSE Window Properties:"
    xwininfo -id $FUSE_WINDOW -display :96
else
    echo "❌ Could not find FUSE window by name"
    echo ""
    echo "All windows on display:"
    xwininfo -root -tree -display :96
fi

echo ""
echo "📐 CAPTURE AREA ANALYSIS"
echo "========================"

# Create a test capture to see what's actually being captured
echo "Creating 5-second test capture to analyze content..."
timeout 5 ffmpeg -f x11grab -video_size 800x600 -framerate 5 -i :96.0+0,0 -y /tmp/fuse_diagnostic.mp4 2>/dev/null

if [ -f /tmp/fuse_diagnostic.mp4 ]; then
    echo "✅ Test capture created: /tmp/fuse_diagnostic.mp4"
    
    # Analyze the video
    echo ""
    echo "📹 CAPTURED VIDEO ANALYSIS"
    echo "=========================="
    ffprobe -v quiet -print_format json -show_streams /tmp/fuse_diagnostic.mp4 | jq -r '.streams[0] | "Resolution: \(.width)x\(.height)\nFrame Rate: \(.r_frame_rate)\nDuration: \(.duration) seconds"'
else
    echo "❌ Could not create test capture"
fi

echo ""
echo "🎯 RECOMMENDATIONS"
echo "=================="

if [ -n "$FUSE_WINDOW" ]; then
    # Get window geometry
    GEOMETRY=$(xwininfo -id $FUSE_WINDOW -display :96 | grep -E "Width:|Height:" | tr '\n' ' ')
    echo "Based on FUSE window analysis:"
    echo "Current FUSE window: $GEOMETRY"
    echo ""
    echo "✅ SOLUTION 1: Use exact window capture"
    echo "   ffmpeg -f x11grab -i :96.0+X,Y -video_size WxH ..."
    echo ""
    echo "✅ SOLUTION 2: Use native ZX Spectrum resolution"
    echo "   Xvfb :95 -screen 0 256x192x24 -ac"
    echo "   ffmpeg -f x11grab -video_size 256x192 -i :95.0+0,0 ..."
    echo ""
    echo "✅ SOLUTION 3: Use 2x native resolution"
    echo "   Xvfb :95 -screen 0 512x384x24 -ac"
    echo "   ffmpeg -f x11grab -video_size 512x384 -i :95.0+0,0 ..."
else
    echo "❌ Could not analyze FUSE window"
    echo ""
    echo "🔧 TROUBLESHOOTING STEPS:"
    echo "1. Check if FUSE is actually running:"
    echo "   ps aux | grep fuse"
    echo ""
    echo "2. Try different FUSE window detection:"
    echo "   xwininfo -root -tree -display :96"
    echo ""
    echo "3. Use native resolution approach:"
    echo "   ./stream_minimal_2x_native_FIXED.sh"
fi

echo ""
echo "🧹 CLEANUP"
echo "=========="
echo "Stopping diagnostic processes..."

# Cleanup
kill $FUSE_PID 2>/dev/null
kill $XVFB_PID 2>/dev/null
sleep 2

echo "✅ Diagnostic complete"
echo ""
echo "📁 Files created:"
echo "   /tmp/fuse_diagnostic.mp4 (if successful)"
echo ""
echo "🚀 Next steps:"
echo "   Try the fixed scripts:"
echo "   ./stream_minimal_2x_native_FIXED.sh"
echo "   ./stream_minimal_2x_adaptive_FIXED.sh"
