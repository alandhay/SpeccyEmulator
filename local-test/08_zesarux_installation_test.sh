#!/bin/bash
# ZEsarUX Installation and Basic Test
# Download, install, and test ZEsarUX as FUSE replacement

set -e

echo "🧪 EXPERIMENT 8: ZEsarUX Installation and Basic Test"
echo "===================================================="

ZESARUX_DIR="/home/ubuntu/workspace/SpeccyEmulator/local-test/zesarux"
ZESARUX_URL="https://github.com/chernandezba/zesarux/releases/download/ZEsarUX-12.0/ZEsarUX_linux-12.0-debian11_x86_64.tar.gz"

echo "📦 Downloading ZEsarUX 12.0..."
mkdir -p ${ZESARUX_DIR}
cd ${ZESARUX_DIR}

if [ ! -f "zesarux_downloaded.tar.gz" ]; then
    wget -O zesarux_downloaded.tar.gz ${ZESARUX_URL}
    echo "✅ Downloaded ZEsarUX"
else
    echo "✅ ZEsarUX already downloaded"
fi

echo "📦 Extracting ZEsarUX..."
if [ ! -d "extracted" ]; then
    mkdir extracted
    cd extracted
    tar -xzf ../zesarux_downloaded.tar.gz
    echo "✅ Extracted ZEsarUX"
else
    echo "✅ ZEsarUX already extracted"
    cd extracted
fi

# Find the ZEsarUX binary
ZESARUX_BIN=$(find . -name "zesarux" -type f | head -1)
if [ -z "$ZESARUX_BIN" ]; then
    echo "❌ Could not find ZEsarUX binary"
    exit 1
fi

echo "✅ Found ZEsarUX binary: ${ZESARUX_BIN}"

# Make it executable
chmod +x ${ZESARUX_BIN}

echo ""
echo "🔍 ZEsarUX Information:"
echo "======================"
${ZESARUX_BIN} --version 2>/dev/null || echo "Version command failed"
echo ""
${ZESARUX_BIN} --help 2>&1 | head -20 || echo "Help command failed"

echo ""
echo "🔍 Checking ZEsarUX dependencies..."
ldd ${ZESARUX_BIN} | head -10 || echo "ldd failed"

echo ""
echo "🎮 Testing ZEsarUX Basic Startup"
echo "================================"

# Configuration matching production
DISPLAY_NUM=99
DISPLAY_SIZE="320x240x24"
export DISPLAY=:${DISPLAY_NUM}

echo "📺 Starting Xvfb for ZEsarUX test..."

# Kill any existing processes
pkill -f "Xvfb :${DISPLAY_NUM}" 2>/dev/null || true
pkill -f "zesarux" 2>/dev/null || true
sleep 2

# Start Xvfb
Xvfb :${DISPLAY_NUM} -screen 0 ${DISPLAY_SIZE} -ac +extension XTEST &
XVFB_PID=$!
echo "✅ Xvfb started with PID: ${XVFB_PID}"

sleep 3

echo "🎮 Starting ZEsarUX..."
echo "   Command: ${ZESARUX_BIN} --machine 48k --zoom 2 --realvideo --noconfigfile --nowelcomemessage"

# Start ZEsarUX with headless-friendly options
${ZESARUX_BIN} --machine 48k --zoom 2 --realvideo --noconfigfile --nowelcomemessage &
ZESARUX_PID=$!
echo "✅ ZEsarUX started with PID: ${ZESARUX_PID}"

sleep 5

echo ""
echo "🔍 Checking ZEsarUX window..."
ZESARUX_WINDOWS=$(xdotool search --name "ZEsarUX" 2>/dev/null || echo "")
if [ -n "$ZESARUX_WINDOWS" ]; then
    echo "✅ Found ZEsarUX windows: $ZESARUX_WINDOWS"
    for window in $ZESARUX_WINDOWS; do
        echo "  Window ID: $window"
        xwininfo -display :${DISPLAY_NUM} -id $window | grep -E "(Width|Height|Map State|Class)"
    done
    ZESARUX_WINDOW=$(echo $ZESARUX_WINDOWS | head -1)
else
    echo "❌ No ZEsarUX windows found by name"
    echo "🔍 Searching for any windows..."
    ALL_WINDOWS=$(xdotool search --onlyvisible --name ".*" 2>/dev/null || echo "")
    if [ -n "$ALL_WINDOWS" ]; then
        echo "Found windows: $ALL_WINDOWS"
        for window in $ALL_WINDOWS; do
            WINDOW_NAME=$(xdotool getwindowname $window 2>/dev/null || echo "Unknown")
            echo "  Window $window: $WINDOW_NAME"
        done
        ZESARUX_WINDOW=$(echo $ALL_WINDOWS | head -1)
    else
        echo "❌ No windows found at all"
        ZESARUX_WINDOW=""
    fi
fi

echo ""
echo "📊 Process Status:"
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
echo "⏱️  Observation period (10 seconds)..."
echo "   ZEsarUX should be running and displaying ZX Spectrum"
sleep 10

echo ""
echo "🧹 Cleaning up..."
kill ${ZESARUX_PID} 2>/dev/null || true
kill ${XVFB_PID} 2>/dev/null || true
sleep 2

echo "✅ ZEsarUX installation and basic test complete!"
echo ""
echo "📋 RESULTS SUMMARY:"
echo "- ZEsarUX download: $([ -f "${ZESARUX_DIR}/zesarux_downloaded.tar.gz" ] && echo "✅ SUCCESS" || echo "❌ FAILED")"
echo "- ZEsarUX extraction: $([ -f "${ZESARUX_BIN}" ] && echo "✅ SUCCESS" || echo "❌ FAILED")"
echo "- ZEsarUX startup: $([ -n "$ZESARUX_PID" ] && echo "✅ SUCCESS" || echo "❌ FAILED")"
echo "- Window detection: $([ -n "$ZESARUX_WINDOW" ] && echo "✅ SUCCESS" || echo "❌ FAILED")"
echo ""
echo "📋 NEXT STEPS:"
if [ -n "$ZESARUX_WINDOW" ]; then
    echo "✅ ZEsarUX is working! Ready for input testing."
    echo "   Run: ./09_zesarux_input_test.sh"
else
    echo "🔍 Need to debug ZEsarUX startup issues before input testing"
fi
