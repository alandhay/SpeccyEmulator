#!/bin/bash
# Integrated Local Test - Complete emulator + server + key testing pipeline
set -e

echo "🧪 INTEGRATED LOCAL TEST: Full ZX Spectrum Emulator Pipeline"
echo "============================================================"
echo "GOAL: Test complete pipeline with visual verification of key presses"

# Configuration
DISPLAY_NUM=99
export DISPLAY=:${DISPLAY_NUM}
WEBSOCKET_PORT=8765
HEALTH_PORT=8080
SCREENSHOT_DIR="/tmp/integrated_test_screenshots"
TEST_LOG="/tmp/integrated_test.log"

# Clean up any existing processes
echo "🧹 Cleaning up existing processes..."
pkill -f "fuse-sdl" 2>/dev/null || true
pkill -f "emulator_server" 2>/dev/null || true
pkill -f "Xvfb.*:${DISPLAY_NUM}" 2>/dev/null || true
sleep 2

# Prepare directories
rm -rf ${SCREENSHOT_DIR}
mkdir -p ${SCREENSHOT_DIR}
rm -f ${TEST_LOG}

echo "📁 Screenshot directory: ${SCREENSHOT_DIR}"
echo "📝 Test log: ${TEST_LOG}"

# Start logging
exec 1> >(tee -a ${TEST_LOG})
exec 2> >(tee -a ${TEST_LOG} >&2)

echo ""
echo "📺 STEP 1: Starting Virtual Display (Xvfb)"
echo "=========================================="

Xvfb :${DISPLAY_NUM} -screen 0 320x240x24 -ac &
XVFB_PID=$!
echo "✅ Xvfb started with PID: ${XVFB_PID} on display :${DISPLAY_NUM}"
sleep 3

echo ""
echo "🎮 STEP 2: Starting FUSE Emulator"
echo "================================="

# Start FUSE emulator in background
fuse-sdl --machine 48 --graphics-filter none --no-sound &
FUSE_PID=$!
echo "✅ FUSE emulator started with PID: ${FUSE_PID}"
sleep 5

# Verify FUSE window exists
FUSE_WINDOW=$(xdotool search --name "Fuse" 2>/dev/null | head -1 || echo "")
if [ -z "$FUSE_WINDOW" ]; then
    echo "❌ FUSE window not found"
    kill ${FUSE_PID} ${XVFB_PID} 2>/dev/null || true
    exit 1
fi
echo "✅ FUSE window found: ${FUSE_WINDOW}"

echo ""
echo "🖥️  STEP 3: Starting Python WebSocket Server"
echo "============================================"

# Set environment variables for server
export SDL_VIDEODRIVER=x11
export SDL_AUDIODRIVER=pulse
export PULSE_RUNTIME_PATH=/tmp/pulse
export STREAM_BUCKET=test-bucket

# Start the server in background
cd /home/ubuntu/workspace/SpeccyEmulator
python3 server/emulator_server_fixed_v5.py &
SERVER_PID=$!
echo "✅ Server started with PID: ${SERVER_PID}"
sleep 5

# Verify server is responding
if ! curl -s http://localhost:${HEALTH_PORT}/health >/dev/null 2>&1; then
    echo "❌ Server health check failed"
    kill ${SERVER_PID} ${FUSE_PID} ${XVFB_PID} 2>/dev/null || true
    exit 1
fi
echo "✅ Server health check passed"

echo ""
echo "📸 STEP 4: Taking Initial Screenshot"
echo "===================================="

# Wait for ZX Spectrum to fully boot
sleep 3

# Take initial screenshot
xwd -display :${DISPLAY_NUM} -id ${FUSE_WINDOW} -out ${SCREENSHOT_DIR}/initial.xwd
echo "✅ Initial screenshot captured"

# Convert to PNG if possible
if command -v convert >/dev/null 2>&1; then
    convert ${SCREENSHOT_DIR}/initial.xwd ${SCREENSHOT_DIR}/initial.png
    echo "✅ Converted to PNG: initial.png"
fi

echo ""
echo "⌨️  STEP 5: Testing Key Input via WebSocket"
echo "==========================================="

# Create a simple WebSocket test client
cat > /tmp/websocket_test_client.py << 'EOF'
#!/usr/bin/env python3
import asyncio
import websockets
import json
import sys

async def test_key_input():
    uri = "ws://localhost:8765"
    
    try:
        async with websockets.connect(uri) as websocket:
            print("✅ WebSocket connected")
            
            # Test individual keys
            test_keys = ['H', 'E', 'L', 'L', 'O', 'SPACE', 'W', 'O', 'R', 'L', 'D']
            
            for key in test_keys:
                message = {
                    "type": "key_press",
                    "key": key
                }
                
                await websocket.send(json.dumps(message))
                print(f"✅ Sent key: {key}")
                
                # Wait for response
                try:
                    response = await asyncio.wait_for(websocket.recv(), timeout=2.0)
                    response_data = json.loads(response)
                    print(f"   Response: {response_data.get('message', 'No message')}")
                except asyncio.TimeoutError:
                    print(f"   ⚠️  No response received for key: {key}")
                
                # Small delay between keys
                await asyncio.sleep(0.5)
                
    except Exception as e:
        print(f"❌ WebSocket test failed: {e}")
        return False
    
    return True

if __name__ == "__main__":
    result = asyncio.run(test_key_input())
    sys.exit(0 if result else 1)
EOF

# Run the WebSocket test
python3 /tmp/websocket_test_client.py
WEBSOCKET_TEST_RESULT=$?

if [ ${WEBSOCKET_TEST_RESULT} -eq 0 ]; then
    echo "✅ WebSocket key test completed"
else
    echo "❌ WebSocket key test failed"
fi

echo ""
echo "📸 STEP 6: Taking After Screenshot"
echo "=================================="

# Wait a moment for keys to be processed
sleep 2

# Take after screenshot
xwd -display :${DISPLAY_NUM} -id ${FUSE_WINDOW} -out ${SCREENSHOT_DIR}/after.xwd
echo "✅ After screenshot captured"

# Convert to PNG
if command -v convert >/dev/null 2>&1; then
    convert ${SCREENSHOT_DIR}/after.xwd ${SCREENSHOT_DIR}/after.png
    echo "✅ Converted to PNG: after.png"
fi

echo ""
echo "🔍 STEP 7: Comparing Screenshots"
echo "================================"

# Compare the files
if cmp -s ${SCREENSHOT_DIR}/initial.xwd ${SCREENSHOT_DIR}/after.xwd; then
    echo "❌ IDENTICAL: Screenshots are identical - key input may NOT be working"
    SCREENSHOTS_DIFFERENT=false
else
    echo "✅ DIFFERENT: Screenshots are different - key input IS working!"
    SCREENSHOTS_DIFFERENT=true
fi

# Check file sizes
INITIAL_SIZE=$(stat -c%s ${SCREENSHOT_DIR}/initial.xwd)
AFTER_SIZE=$(stat -c%s ${SCREENSHOT_DIR}/after.xwd)
echo "Initial screenshot size: ${INITIAL_SIZE} bytes"
echo "After screenshot size: ${AFTER_SIZE} bytes"

echo ""
echo "🔍 STEP 8: Direct xdotool Test (Bypass Server)"
echo "=============================================="

echo "Testing direct xdotool key injection..."

# Take a screenshot before direct test
xwd -display :${DISPLAY_NUM} -id ${FUSE_WINDOW} -out ${SCREENSHOT_DIR}/before_direct.xwd

# Send keys directly via xdotool
echo "Sending 'TEST' directly via xdotool..."
xdotool search --name "Fuse" windowfocus key t
sleep 0.5
xdotool search --name "Fuse" windowfocus key e
sleep 0.5
xdotool search --name "Fuse" windowfocus key s
sleep 0.5
xdotool search --name "Fuse" windowfocus key t
sleep 1

# Take screenshot after direct test
xwd -display :${DISPLAY_NUM} -id ${FUSE_WINDOW} -out ${SCREENSHOT_DIR}/after_direct.xwd

# Compare direct test screenshots
if cmp -s ${SCREENSHOT_DIR}/before_direct.xwd ${SCREENSHOT_DIR}/after_direct.xwd; then
    echo "❌ Direct xdotool test: No change detected"
    DIRECT_TEST_WORKS=false
else
    echo "✅ Direct xdotool test: Change detected!"
    DIRECT_TEST_WORKS=true
fi

echo ""
echo "🧹 STEP 9: Cleanup"
echo "=================="

echo "Stopping all processes..."
kill ${SERVER_PID} ${FUSE_PID} ${XVFB_PID} 2>/dev/null || true
sleep 2

echo ""
echo "📋 FINAL TEST RESULTS"
echo "====================="
echo "- WebSocket test: $([ ${WEBSOCKET_TEST_RESULT} -eq 0 ] && echo "✅ PASSED" || echo "❌ FAILED")"
echo "- Screenshots different (WebSocket): $([ "$SCREENSHOTS_DIFFERENT" = "true" ] && echo "✅ YES" || echo "❌ NO")"
echo "- Direct xdotool test: $([ "$DIRECT_TEST_WORKS" = "true" ] && echo "✅ WORKS" || echo "❌ FAILED")"
echo "- Initial size: ${INITIAL_SIZE} bytes"
echo "- After size: ${AFTER_SIZE} bytes"
echo ""

# Overall conclusion
if [ ${WEBSOCKET_TEST_RESULT} -eq 0 ] && [ "$SCREENSHOTS_DIFFERENT" = "true" ]; then
    echo "🎉 OVERALL RESULT: ✅ SUCCESS - Full pipeline is working!"
    echo "   - WebSocket server accepts key commands"
    echo "   - Key commands reach the FUSE emulator"
    echo "   - Visual changes are detected in screenshots"
elif [ "$DIRECT_TEST_WORKS" = "true" ]; then
    echo "⚠️  OVERALL RESULT: 🔧 PARTIAL SUCCESS"
    echo "   - Direct xdotool works (emulator responds to keys)"
    echo "   - WebSocket pipeline may have issues"
    echo "   - Check server logs for WebSocket→xdotool translation"
else
    echo "❌ OVERALL RESULT: ❌ FAILURE"
    echo "   - Neither WebSocket nor direct xdotool is working"
    echo "   - Check FUSE emulator configuration"
    echo "   - Check X11 display and window focus"
fi

echo ""
echo "📁 Test artifacts saved to: ${SCREENSHOT_DIR}/"
echo "📝 Full test log saved to: ${TEST_LOG}"
echo ""
echo "🔍 To view screenshots:"
if command -v convert >/dev/null 2>&1; then
    echo "   - Initial: ${SCREENSHOT_DIR}/initial.png"
    echo "   - After WebSocket: ${SCREENSHOT_DIR}/after.png"
    echo "   - Before direct: ${SCREENSHOT_DIR}/before_direct.png (if converted)"
    echo "   - After direct: ${SCREENSHOT_DIR}/after_direct.png (if converted)"
else
    echo "   - Install ImageMagick to convert XWD files to PNG"
    echo "   - Or use: xwud -in ${SCREENSHOT_DIR}/initial.xwd"
fi
