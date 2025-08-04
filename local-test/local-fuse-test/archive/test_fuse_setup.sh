#!/bin/bash

# Test FUSE Emulator Setup and Installation
echo "🔧 FUSE Emulator Setup Test"
echo "==========================="

echo ""
echo "📋 Step 1: Checking FUSE installation..."
echo "========================================"

# Check if FUSE is installed
if command -v fuse-sdl &> /dev/null; then
    echo "✅ fuse-sdl found: $(which fuse-sdl)"
    echo "📄 Version info:"
    fuse-sdl --version 2>/dev/null || echo "   Version info not available"
else
    echo "❌ fuse-sdl not found!"
    echo ""
    echo "🔧 Installing FUSE emulator..."
    sudo apt-get update
    sudo apt-get install -y fuse-emulator-sdl
    
    if command -v fuse-sdl &> /dev/null; then
        echo "✅ FUSE installed successfully!"
    else
        echo "❌ FUSE installation failed!"
        exit 1
    fi
fi

echo ""
echo "📋 Step 2: Checking X11 and display tools..."
echo "============================================"

# Check Xvfb
if command -v Xvfb &> /dev/null; then
    echo "✅ Xvfb found: $(which Xvfb)"
else
    echo "❌ Xvfb not found! Installing..."
    sudo apt-get install -y xvfb
fi

# Check xwininfo
if command -v xwininfo &> /dev/null; then
    echo "✅ xwininfo found: $(which xwininfo)"
else
    echo "❌ xwininfo not found! Installing..."
    sudo apt-get install -y x11-utils
fi

echo ""
echo "📋 Step 3: Testing virtual display..."
echo "====================================="

DISPLAY_NUM=":98"
export DISPLAY=$DISPLAY_NUM

# Start test virtual display
echo "Starting test virtual display $DISPLAY_NUM..."
Xvfb $DISPLAY_NUM -screen 0 1280x720x24 -ac +extension GLX &
XVFB_PID=$!
sleep 3

if pgrep -f "Xvfb $DISPLAY_NUM" > /dev/null; then
    echo "✅ Virtual display started successfully (PID: $XVFB_PID)"
    
    # Test display info
    echo "📊 Display info:"
    xdpyinfo -display $DISPLAY_NUM 2>/dev/null | head -10 || echo "   Display info not available"
    
    # Kill test display
    kill $XVFB_PID
    echo "✅ Test display stopped"
else
    echo "❌ Failed to start virtual display!"
    exit 1
fi

echo ""
echo "📋 Step 4: Testing FUSE startup (5-second test)..."
echo "=================================================="

# Start virtual display for FUSE test
export DISPLAY=$DISPLAY_NUM
Xvfb $DISPLAY_NUM -screen 0 1280x720x24 -ac +extension GLX &
XVFB_PID=$!
sleep 3

echo "Starting FUSE for 5-second test..."
timeout 5s fuse-sdl --machine 48 --no-sound &
FUSE_PID=$!
sleep 6

if pgrep -f fuse-sdl > /dev/null; then
    echo "⚠️ FUSE still running (killing it now)"
    pkill -f fuse-sdl
else
    echo "✅ FUSE started and stopped correctly"
fi

# Cleanup
kill $XVFB_PID 2>/dev/null || true

echo ""
echo "📋 Step 5: Checking FFmpeg capabilities..."
echo "=========================================="

if command -v ffmpeg &> /dev/null; then
    echo "✅ FFmpeg found: $(which ffmpeg)"
    echo "📄 Version: $(ffmpeg -version 2>/dev/null | head -1)"
    
    # Test X11 grab capability
    echo "🔍 Testing X11 grab capability..."
    if ffmpeg -f x11grab -list_devices true -i dummy 2>&1 | grep -q "x11grab"; then
        echo "✅ X11 grab support available"
    else
        echo "❌ X11 grab support missing!"
    fi
    
    # Test lavfi support
    echo "🔍 Testing lavfi (synthetic input) support..."
    if ffmpeg -f lavfi -i "color=red:size=320x240:rate=1" -t 1 -f null - 2>/dev/null; then
        echo "✅ lavfi support working"
    else
        echo "❌ lavfi support issues!"
    fi
    
else
    echo "❌ FFmpeg not found!"
    echo "🔧 Installing FFmpeg..."
    sudo apt-get install -y ffmpeg
fi

echo ""
echo "📊 Setup Test Summary:"
echo "======================"
echo "✅ FUSE emulator: $(command -v fuse-sdl &> /dev/null && echo "READY" || echo "MISSING")"
echo "✅ Virtual display: $(command -v Xvfb &> /dev/null && echo "READY" || echo "MISSING")"
echo "✅ FFmpeg: $(command -v ffmpeg &> /dev/null && echo "READY" || echo "MISSING")"
echo "✅ X11 tools: $(command -v xwininfo &> /dev/null && echo "READY" || echo "MISSING")"
echo ""
echo "🎯 If all components show READY:"
echo "   → Run ./stream_fuse_to_youtube.sh to start streaming"
echo ""
echo "🎯 If any components show MISSING:"
echo "   → Install missing components and run this test again"
echo ""
echo "💡 Troubleshooting:"
echo "   → Check /var/log/apt/ for installation issues"
echo "   → Verify internet connection for package downloads"
echo "   → Run with sudo if permission errors occur"
