#!/bin/bash
# SDL Input Method Fix - Test different SDL configurations
# The issue is likely SDL not receiving X11 input in headless mode

set -e

echo "🧪 EXPERIMENT 6: SDL Input Method Fix"
echo "===================================="

# Configuration matching production
DISPLAY_NUM=99
DISPLAY_SIZE="320x240x24"
export DISPLAY=:${DISPLAY_NUM}

echo "📺 Starting Xvfb with full input support..."

# Kill any existing processes
pkill -f "Xvfb :${DISPLAY_NUM}" 2>/dev/null || true
pkill -f "fuse-sdl" 2>/dev/null || true
sleep 2

# Start Xvfb with comprehensive input support
Xvfb :${DISPLAY_NUM} -screen 0 ${DISPLAY_SIZE} -ac -nolisten tcp +extension XTEST +extension XKEYBOARD &
XVFB_PID=$!
echo "✅ Xvfb started with PID: ${XVFB_PID}"

# Wait for X server to be ready
sleep 3

echo ""
echo "🔧 SDL CONFIGURATION TEST 1: Default SDL settings"
echo "================================================="

# Test with default SDL settings
export SDL_VIDEODRIVER=x11
export SDL_AUDIODRIVER=pulse

echo "🎮 Starting FUSE with SDL_VIDEODRIVER=x11..."
fuse-sdl --machine 48 --no-sound &
FUSE_PID=$!
echo "✅ FUSE started with PID: ${FUSE_PID}"

sleep 5

# Test input
FUSE_WINDOW=$(xdotool search --name "Fuse" 2>/dev/null | head -1)
echo "Found FUSE window: ${FUSE_WINDOW}"

# Monitor and test
strace -p ${FUSE_PID} -e trace=read,poll,select -o /tmp/sdl_test1.log 2>/dev/null &
STRACE_PID=$!
sleep 1

echo "Sending test key..."
xdotool key --window ${FUSE_WINDOW} Return
sleep 3

kill ${STRACE_PID} 2>/dev/null || true
EVENTS1=$(wc -l < /tmp/sdl_test1.log 2>/dev/null || echo "0")
echo "📊 Test 1 events: ${EVENTS1}"

# Kill FUSE for next test
kill ${FUSE_PID} 2>/dev/null || true
sleep 2

echo ""
echo "🔧 SDL CONFIGURATION TEST 2: Force input grab"
echo "=============================================="

# Test with input grab forced
export SDL_GRAB_KEYBOARD=1
export SDL_GRAB_MOUSE=1

echo "🎮 Starting FUSE with input grab enabled..."
fuse-sdl --machine 48 --no-sound &
FUSE_PID=$!
echo "✅ FUSE started with PID: ${FUSE_PID}"

sleep 5

FUSE_WINDOW=$(xdotool search --name "Fuse" 2>/dev/null | head -1)
echo "Found FUSE window: ${FUSE_WINDOW}"

# Monitor and test
strace -p ${FUSE_PID} -e trace=read,poll,select -o /tmp/sdl_test2.log 2>/dev/null &
STRACE_PID=$!
sleep 1

echo "Sending test key with grab..."
xdotool key --window ${FUSE_WINDOW} Return
sleep 3

kill ${STRACE_PID} 2>/dev/null || true
EVENTS2=$(wc -l < /tmp/sdl_test2.log 2>/dev/null || echo "0")
echo "📊 Test 2 events: ${EVENTS2}"

kill ${FUSE_PID} 2>/dev/null || true
sleep 2

echo ""
echo "🔧 SDL CONFIGURATION TEST 3: Alternative approach - Use xvkbd"
echo "============================================================"

# Test with xvkbd (virtual keyboard) if available
if command -v xvkbd >/dev/null 2>&1; then
    echo "🎮 Starting FUSE for xvkbd test..."
    fuse-sdl --machine 48 --no-sound &
    FUSE_PID=$!
    sleep 5
    
    FUSE_WINDOW=$(xdotool search --name "Fuse" 2>/dev/null | head -1)
    
    strace -p ${FUSE_PID} -e trace=read,poll,select -o /tmp/sdl_test3.log 2>/dev/null &
    STRACE_PID=$!
    sleep 1
    
    echo "Using xvkbd for input..."
    echo -e "\\r" | xvkbd -xsendevent -text -
    sleep 3
    
    kill ${STRACE_PID} 2>/dev/null || true
    EVENTS3=$(wc -l < /tmp/sdl_test3.log 2>/dev/null || echo "0")
    echo "📊 Test 3 events: ${EVENTS3}"
    
    kill ${FUSE_PID} 2>/dev/null || true
else
    echo "xvkbd not available, skipping test 3"
    EVENTS3=0
fi

sleep 2

echo ""
echo "🔧 FINAL TEST: Check if FUSE is actually SDL-based"
echo "================================================="

echo "🔍 Checking FUSE binary dependencies..."
ldd $(which fuse-sdl) | grep -i sdl || echo "No SDL dependencies found"

echo ""
echo "🔍 Checking FUSE help for input options..."
fuse-sdl --help 2>&1 | grep -i -E "(input|keyboard|joystick)" || echo "No input options found"

echo ""
echo "📊 RESULTS SUMMARY:"
echo "=================="
echo "Test 1 (default SDL): ${EVENTS1} events"
echo "Test 2 (input grab): ${EVENTS2} events"
echo "Test 3 (xvkbd): ${EVENTS3} events"

if [ "$EVENTS1" -gt "0" ] || [ "$EVENTS2" -gt "0" ] || [ "$EVENTS3" -gt "0" ]; then
    echo "✅ SUCCESS! Found working input method!"
    
    if [ "$EVENTS1" -gt "0" ]; then
        echo "🎯 SOLUTION: Default SDL configuration works"
    elif [ "$EVENTS2" -gt "0" ]; then
        echo "🎯 SOLUTION: SDL input grab required"
        echo "   Add: export SDL_GRAB_KEYBOARD=1"
        echo "   Add: export SDL_GRAB_MOUSE=1"
    elif [ "$EVENTS3" -gt "0" ]; then
        echo "🎯 SOLUTION: Use xvkbd instead of xdotool"
    fi
else
    echo "❌ NONE of the SDL methods worked"
    echo "🔍 This suggests FUSE may not be properly SDL-based or needs different approach"
fi

echo ""
echo "🧹 Cleaning up..."
kill ${XVFB_PID} 2>/dev/null || true
rm -f /tmp/sdl_test*.log
sleep 2

echo "✅ SDL input method test complete!"
echo ""
echo "📋 NEXT STEPS:"
echo "- If a method worked: Implement in production server"
echo "- If no methods worked: Consider alternative emulator or input method"
echo "- Check production logs for SDL-related errors"
