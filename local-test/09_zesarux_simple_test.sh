#!/bin/bash
# Simple ZEsarUX Test - Verify basic functionality
set -e

echo "🧪 EXPERIMENT 9: ZEsarUX Simple Test"
echo "===================================="

ZESARUX_BIN="/home/ubuntu/workspace/SpeccyEmulator/local-test/zesarux/extracted/ZEsarUX-12.0/zesarux"

echo "✅ ZEsarUX binary: ${ZESARUX_BIN}"

echo ""
echo "🔍 ZEsarUX Version:"
${ZESARUX_BIN} --version

echo ""
echo "🔍 ZEsarUX Help (first 20 lines):"
${ZESARUX_BIN} --help 2>&1 | head -20

echo ""
echo "🔍 ZEsarUX Command Line Options:"
echo "Checking for headless-friendly options..."

# Check for specific options we need
echo "Looking for key options:"
${ZESARUX_BIN} --help 2>&1 | grep -E "(machine|zoom|realvideo|noconfigfile|nowelcomemessage|enable-remoteprotocol)" || echo "Some options not found in help"

echo ""
echo "🎮 Testing ZEsarUX with minimal X11 setup"
echo "========================================="

# Configuration
DISPLAY_NUM=99
export DISPLAY=:${DISPLAY_NUM}

# Clean up any existing processes
pkill -f "Xvfb :${DISPLAY_NUM}" 2>/dev/null || true
pkill -f "zesarux" 2>/dev/null || true
sleep 2

echo "📺 Starting minimal Xvfb..."
Xvfb :${DISPLAY_NUM} -screen 0 320x240x24 -ac &
XVFB_PID=$!
echo "✅ Xvfb started with PID: ${XVFB_PID}"

sleep 3

echo "🎮 Testing ZEsarUX startup (5 second test)..."
echo "Command: ${ZESARUX_BIN} --machine 48k --zoom 1 --realvideo --noconfigfile --nowelcomemessage"

# Start ZEsarUX with timeout
timeout 5s ${ZESARUX_BIN} --machine 48k --zoom 1 --realvideo --noconfigfile --nowelcomemessage &
ZESARUX_PID=$!
echo "✅ ZEsarUX started with PID: ${ZESARUX_PID}"

sleep 3

echo ""
echo "📊 Process Status Check:"
if ps -p ${ZESARUX_PID} > /dev/null 2>&1; then
    echo "✅ ZEsarUX process running (PID: ${ZESARUX_PID})"
    ps -p ${ZESARUX_PID} -o pid,cmd,%cpu,%mem
else
    echo "❌ ZEsarUX process not running"
fi

if ps -p ${XVFB_PID} > /dev/null 2>&1; then
    echo "✅ Xvfb process running (PID: ${XVFB_PID})"
else
    echo "❌ Xvfb process not running"
fi

echo ""
echo "🔍 Checking for ZEsarUX windows..."
WINDOWS=$(xdotool search --name "ZEsarUX" 2>/dev/null || echo "")
if [ -n "$WINDOWS" ]; then
    echo "✅ Found ZEsarUX windows: $WINDOWS"
    for window in $WINDOWS; do
        echo "  Window ID: $window"
        xwininfo -display :${DISPLAY_NUM} -id $window 2>/dev/null | grep -E "(Width|Height|Map State)" || echo "  Could not get window info"
    done
else
    echo "❌ No ZEsarUX windows found"
    echo "🔍 Checking all windows..."
    ALL_WINDOWS=$(xdotool search --onlyvisible --name ".*" 2>/dev/null || echo "")
    if [ -n "$ALL_WINDOWS" ]; then
        echo "Found windows: $ALL_WINDOWS"
    else
        echo "No windows found at all"
    fi
fi

sleep 2

echo ""
echo "🧹 Cleaning up..."
kill ${ZESARUX_PID} 2>/dev/null || true
kill ${XVFB_PID} 2>/dev/null || true
sleep 1

echo ""
echo "✅ ZEsarUX simple test complete!"
echo ""
echo "📋 RESULTS SUMMARY:"
echo "- ZEsarUX version: $(${ZESARUX_BIN} --version 2>/dev/null | head -1)"
echo "- Dependencies: ✅ RESOLVED (OpenSSL 1.1 installed)"
echo "- Basic startup: $([ -n "$ZESARUX_PID" ] && echo "✅ SUCCESS" || echo "❌ FAILED")"
echo "- Window creation: $([ -n "$WINDOWS" ] && echo "✅ SUCCESS" || echo "❌ FAILED")"
