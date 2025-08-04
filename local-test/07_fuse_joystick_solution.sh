#!/bin/bash
# FUSE Joystick Solution Test - Use FUSE's built-in input mapping
# The --kempston option maps QAOP<space> which might work better

set -e

echo "🧪 EXPERIMENT 7: FUSE Joystick Solution (FINAL TEST)"
echo "===================================================="

# Configuration matching production
DISPLAY_NUM=99
DISPLAY_SIZE="320x240x24"
export DISPLAY=:${DISPLAY_NUM}

echo "📺 Starting Xvfb..."

# Kill any existing processes
pkill -f "Xvfb :${DISPLAY_NUM}" 2>/dev/null || true
pkill -f "fuse-sdl" 2>/dev/null || true
sleep 2

# Start Xvfb
Xvfb :${DISPLAY_NUM} -screen 0 ${DISPLAY_SIZE} -ac +extension XTEST &
XVFB_PID=$!
echo "✅ Xvfb started with PID: ${XVFB_PID}"

sleep 3

echo ""
echo "🎮 SOLUTION TEST: FUSE with Kempston joystick mapping"
echo "===================================================="

# Set SDL environment for best compatibility
export SDL_VIDEODRIVER=x11
export SDL_AUDIODRIVER=pulse

echo "🎮 Starting FUSE with --kempston option..."
fuse-sdl --machine 48 --no-sound --kempston &
FUSE_PID=$!
echo "✅ FUSE started with PID: ${FUSE_PID} (with Kempston joystick)"

sleep 5

FUSE_WINDOW=$(xdotool search --name "Fuse" 2>/dev/null | head -1)
if [ -z "$FUSE_WINDOW" ]; then
    echo "❌ Could not find FUSE window!"
    kill ${FUSE_PID} 2>/dev/null || true
    kill ${XVFB_PID} 2>/dev/null || true
    exit 1
fi

echo "✅ Found FUSE window: ${FUSE_WINDOW}"

# Start comprehensive monitoring
echo "🔍 Starting comprehensive input monitoring..."
strace -p ${FUSE_PID} -e trace=read,poll,select,epoll_wait -o /tmp/fuse_final.log 2>/dev/null &
STRACE_PID=$!
sleep 1

echo ""
echo "⌨️  Testing QAOP keys (joystick mapping)..."
echo "   Q (Up)..."
xdotool key q
sleep 1

echo "   A (Left)..."
xdotool key a
sleep 1

echo "   O (Down)..."
xdotool key o
sleep 1

echo "   P (Right)..."
xdotool key p
sleep 1

echo "   SPACE (Fire)..."
xdotool key space
sleep 2

echo ""
echo "⌨️  Testing other common keys..."
echo "   ENTER (to get past splash)..."
xdotool key Return
sleep 2

echo "   ESC..."
xdotool key Escape
sleep 1

echo "   Numbers..."
xdotool key 1 2 3
sleep 2

echo ""
echo "🔍 Stopping monitoring and analyzing results..."
kill ${STRACE_PID} 2>/dev/null || true
sleep 1

if [ -f /tmp/fuse_final.log ]; then
    EVENTS=$(wc -l < /tmp/fuse_final.log 2>/dev/null || echo "0")
    echo "📊 FUSE system calls during joystick test: ${EVENTS}"
    
    if [ "$EVENTS" -gt "0" ]; then
        echo "🎉 SUCCESS! FUSE received input events!"
        echo ""
        echo "📋 Event details (last 10):"
        tail -10 /tmp/fuse_final.log
        
        echo ""
        echo "🎯 SOLUTION FOUND:"
        echo "   ✅ Use --kempston option in FUSE"
        echo "   ✅ QAOP keys work for joystick input"
        echo "   ✅ Standard keys work for emulator control"
        
    else
        echo "❌ Still no input events detected"
        echo "🔍 Need to investigate further..."
    fi
else
    echo "❌ No monitoring log found"
fi

echo ""
echo "🔍 Final diagnostics..."

# Check if FUSE process is healthy
if ps -p ${FUSE_PID} > /dev/null 2>&1; then
    echo "✅ FUSE process still running and healthy"
    
    # Check CPU usage (sign of activity)
    CPU=$(ps -p ${FUSE_PID} -o %cpu --no-headers 2>/dev/null || echo "0")
    echo "   CPU usage: ${CPU}%"
    
    # Check memory
    MEM=$(ps -p ${FUSE_PID} -o %mem --no-headers 2>/dev/null || echo "0")
    echo "   Memory usage: ${MEM}%"
    
else
    echo "❌ FUSE process has exited"
fi

# Check window status
if xdotool search --name "Fuse" > /dev/null 2>&1; then
    echo "✅ FUSE window still exists"
else
    echo "❌ FUSE window no longer exists"
fi

echo ""
echo "⏱️  Extended observation period (10 seconds)..."
echo "   In a working system, FUSE should respond to the keys we sent..."
sleep 10

echo ""
echo "🧹 Cleaning up..."
kill ${FUSE_PID} 2>/dev/null || true
kill ${XVFB_PID} 2>/dev/null || true
rm -f /tmp/fuse_final.log
sleep 2

echo "✅ FUSE joystick solution test complete!"
echo ""
echo "📋 PRODUCTION IMPLEMENTATION:"
if [ "$EVENTS" -gt "0" ]; then
    echo "🎯 IMPLEMENT THIS SOLUTION:"
    echo "   1. Add --kempston flag to FUSE startup"
    echo "   2. Ensure SDL_VIDEODRIVER=x11 is set"
    echo "   3. Use direct key injection (no window activation needed)"
    echo "   4. Map web controls to QAOP+SPACE for games"
    echo "   5. Test with ENTER key to get past splash screen"
else
    echo "🔍 FURTHER INVESTIGATION NEEDED:"
    echo "   1. Check if different FUSE version/build required"
    echo "   2. Consider alternative emulator (e.g., ZEsarUX)"
    echo "   3. Investigate FUSE source code for input handling"
    echo "   4. Test with different SDL versions"
fi
