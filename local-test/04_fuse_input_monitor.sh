#!/bin/bash
# FUSE Input Monitoring Test - Monitor if FUSE actually receives input events
# This will help us determine if the keys are reaching FUSE or being lost

set -e

echo "🧪 EXPERIMENT 4: FUSE Input Monitoring"
echo "======================================"

# Configuration matching production
DISPLAY_NUM=99
DISPLAY_SIZE="320x240x24"
export DISPLAY=:${DISPLAY_NUM}

echo "📺 Starting Xvfb on display :${DISPLAY_NUM}"

# Kill any existing processes
pkill -f "Xvfb :${DISPLAY_NUM}" 2>/dev/null || true
pkill -f "fuse-sdl" 2>/dev/null || true
sleep 2

# Start Xvfb
Xvfb :${DISPLAY_NUM} -screen 0 ${DISPLAY_SIZE} -ac &
XVFB_PID=$!
echo "✅ Xvfb started with PID: ${XVFB_PID}"

# Wait for X server to be ready
sleep 3

echo "🎮 Starting FUSE emulator..."
fuse-sdl --machine 48 --no-sound &
FUSE_PID=$!
echo "✅ FUSE started with PID: ${FUSE_PID}"

# Wait for FUSE to initialize
sleep 5

echo "🔍 Finding FUSE window..."
FUSE_WINDOW=$(xdotool search --name "Fuse" 2>/dev/null | head -1)
if [ -z "$FUSE_WINDOW" ]; then
    echo "❌ Could not find FUSE window!"
    kill ${FUSE_PID} 2>/dev/null || true
    kill ${XVFB_PID} 2>/dev/null || true
    exit 1
fi

echo "✅ Found FUSE window: ${FUSE_WINDOW}"

echo ""
echo "🔍 Starting system call monitoring on FUSE process..."
echo "   This will show us if FUSE receives any input events..."

# Start strace in background to monitor FUSE
strace -p ${FUSE_PID} -e trace=read,poll,select,epoll_wait -o /tmp/fuse_strace.log 2>/dev/null &
STRACE_PID=$!
sleep 2

echo "✅ strace monitoring started (PID: ${STRACE_PID})"

echo ""
echo "⌨️  Sending test keys and monitoring FUSE response..."

echo "   Baseline: Waiting 3 seconds (no input)..."
sleep 3

echo "   Sending ENTER key..."
DISPLAY=:${DISPLAY_NUM} xdotool key Return
sleep 2

echo "   Sending SPACE key..."
DISPLAY=:${DISPLAY_NUM} xdotool key space
sleep 2

echo "   Sending letter 'A'..."
DISPLAY=:${DISPLAY_NUM} xdotool key a
sleep 2

echo "   Sending ESC key..."
DISPLAY=:${DISPLAY_NUM} xdotool key Escape
sleep 2

echo ""
echo "🔍 Stopping monitoring and analyzing results..."
kill ${STRACE_PID} 2>/dev/null || true
sleep 1

echo ""
echo "📊 STRACE ANALYSIS:"
if [ -f /tmp/fuse_strace.log ]; then
    echo "--- System calls during key injection ---"
    cat /tmp/fuse_strace.log | tail -20
    echo ""
    
    # Count different types of system calls
    READ_CALLS=$(grep -c "read(" /tmp/fuse_strace.log 2>/dev/null || echo "0")
    POLL_CALLS=$(grep -c "poll(" /tmp/fuse_strace.log 2>/dev/null || echo "0")
    SELECT_CALLS=$(grep -c "select(" /tmp/fuse_strace.log 2>/dev/null || echo "0")
    
    echo "📈 System call summary:"
    echo "   read() calls: ${READ_CALLS}"
    echo "   poll() calls: ${POLL_CALLS}"
    echo "   select() calls: ${SELECT_CALLS}"
    
    if [ "$READ_CALLS" -gt "0" ] || [ "$POLL_CALLS" -gt "0" ]; then
        echo "✅ FUSE is receiving input events!"
    else
        echo "❌ FUSE is NOT receiving input events"
    fi
else
    echo "❌ No strace log found"
fi

echo ""
echo "🔍 Checking FUSE process status..."
if ps -p ${FUSE_PID} > /dev/null 2>&1; then
    echo "✅ FUSE process still running"
    
    # Get more detailed process info
    echo "📊 Process details:"
    ps -p ${FUSE_PID} -o pid,ppid,cmd,%cpu,%mem,stat
    
    # Check file descriptors
    echo "📁 Open file descriptors:"
    ls -la /proc/${FUSE_PID}/fd/ 2>/dev/null | head -10
else
    echo "❌ FUSE process has exited"
fi

echo ""
echo "🔍 Checking X11 connection..."
echo "   X11 connections to display :${DISPLAY_NUM}:"
netstat -x 2>/dev/null | grep -i x11 || echo "   No X11 connections found via netstat"

echo ""
echo "⏱️  Final observation period (5 seconds)..."
sleep 5

echo ""
echo "🧹 Cleaning up..."
kill ${FUSE_PID} 2>/dev/null || true
kill ${XVFB_PID} 2>/dev/null || true
rm -f /tmp/fuse_strace.log
sleep 2

echo "✅ FUSE input monitoring test complete!"
echo ""
echo "📋 KEY FINDINGS:"
echo "- Check if FUSE received any input events in the strace output above"
echo "- If no events: Problem is in X11 key delivery"
echo "- If events present: Problem is in FUSE input processing"
echo "- This will guide our next debugging steps"
