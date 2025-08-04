#!/bin/bash
# Complete WebSocket Pipeline Test
set -e

echo "🌐 WEBSOCKET PIPELINE TEST"
echo "=========================="
echo "GOAL: Test complete WebSocket → xdotool → FUSE pipeline with visual proof"

# Configuration
DISPLAY_NUM=99
export DISPLAY=:${DISPLAY_NUM}
WEBSOCKET_PORT=8765
SCREENSHOT_DIR="/tmp/websocket_pipeline_test"

# Clean up
echo "🧹 Cleaning up existing processes..."
pkill -f "fuse-sdl" 2>/dev/null || true
pkill -f "websocket_key_test.py" 2>/dev/null || true
pkill -f "Xvfb.*:${DISPLAY_NUM}" 2>/dev/null || true
rm -rf ${SCREENSHOT_DIR}
mkdir -p ${SCREENSHOT_DIR}
sleep 2

echo ""
echo "📺 STEP 1: Starting Virtual Display"
echo "==================================="
Xvfb :${DISPLAY_NUM} -screen 0 320x240x24 -ac &
XVFB_PID=$!
echo "✅ Xvfb started with PID: ${XVFB_PID}"
sleep 3

echo ""
echo "🎮 STEP 2: Starting FUSE Emulator"
echo "================================="
fuse-sdl --machine 48 --no-sound &
FUSE_PID=$!
echo "✅ FUSE emulator started with PID: ${FUSE_PID}"
sleep 5

# Find FUSE window
FUSE_WINDOW=$(xdotool search --name "Fuse" 2>/dev/null | head -1 || echo "")
if [ -z "$FUSE_WINDOW" ]; then
    echo "❌ FUSE window not found"
    kill ${FUSE_PID} ${XVFB_PID} 2>/dev/null || true
    exit 1
fi
echo "✅ FUSE window found: ${FUSE_WINDOW}"

echo ""
echo "🌐 STEP 3: Starting WebSocket Server"
echo "===================================="
cd /home/ubuntu/workspace/SpeccyEmulator
python3 local-test/websocket_key_test.py &
SERVER_PID=$!
echo "✅ WebSocket server started with PID: ${SERVER_PID}"
sleep 3

# Test if server is responding
if ! netstat -ln | grep -q ":${WEBSOCKET_PORT} "; then
    echo "❌ WebSocket server not listening on port ${WEBSOCKET_PORT}"
    kill ${SERVER_PID} ${FUSE_PID} ${XVFB_PID} 2>/dev/null || true
    exit 1
fi
echo "✅ WebSocket server is listening on port ${WEBSOCKET_PORT}"

echo ""
echo "📸 STEP 4: Taking BEFORE Screenshot"
echo "==================================="
sleep 3  # Wait for ZX Spectrum to boot

xwd -display :${DISPLAY_NUM} -id ${FUSE_WINDOW} -out ${SCREENSHOT_DIR}/before.xwd
echo "✅ Before screenshot captured"

if command -v convert >/dev/null 2>&1; then
    convert ${SCREENSHOT_DIR}/before.xwd ${SCREENSHOT_DIR}/before.png
    echo "✅ Converted to PNG: before.png"
fi

echo ""
echo "🌐 STEP 5: Testing WebSocket Key Commands"
echo "========================================"

# Create WebSocket test client
cat > /tmp/websocket_test_client.py << 'EOF'
#!/usr/bin/env python3
import asyncio
import websockets
import json
import sys

async def test_websocket_keys():
    uri = "ws://localhost:8765"
    
    try:
        async with websockets.connect(uri) as websocket:
            print("✅ WebSocket connected")
            
            # Wait for welcome message
            welcome = await websocket.recv()
            welcome_data = json.loads(welcome)
            print(f"Server says: {welcome_data.get('message')}")
            
            # Test key sequence
            test_keys = ['H', 'E', 'L', 'L', 'O', 'SPACE', 'T', 'E', 'S', 'T']
            
            for key in test_keys:
                message = {
                    "type": "key_press",
                    "key": key
                }
                
                print(f"Sending key: {key}")
                await websocket.send(json.dumps(message))
                
                # Wait for response
                try:
                    response = await asyncio.wait_for(websocket.recv(), timeout=3.0)
                    response_data = json.loads(response)
                    
                    if response_data.get('success'):
                        print(f"  ✅ {response_data.get('message')}")
                    else:
                        print(f"  ❌ {response_data.get('message')}")
                        
                except asyncio.TimeoutError:
                    print(f"  ⚠️  Timeout waiting for response to key: {key}")
                
                # Small delay between keys
                await asyncio.sleep(0.5)
            
            print("✅ All keys sent successfully")
            return True
                
    except Exception as e:
        print(f"❌ WebSocket test failed: {e}")
        return False

if __name__ == "__main__":
    result = asyncio.run(test_websocket_keys())
    sys.exit(0 if result else 1)
EOF

# Run the WebSocket test
echo "Running WebSocket client test..."
python3 /tmp/websocket_test_client.py
WEBSOCKET_TEST_RESULT=$?

if [ ${WEBSOCKET_TEST_RESULT} -eq 0 ]; then
    echo "✅ WebSocket test completed successfully"
else
    echo "❌ WebSocket test failed"
fi

echo ""
echo "📸 STEP 6: Taking AFTER Screenshot"
echo "=================================="
sleep 2  # Wait for keys to be processed

xwd -display :${DISPLAY_NUM} -id ${FUSE_WINDOW} -out ${SCREENSHOT_DIR}/after.xwd
echo "✅ After screenshot captured"

if command -v convert >/dev/null 2>&1; then
    convert ${SCREENSHOT_DIR}/after.xwd ${SCREENSHOT_DIR}/after.png
    echo "✅ Converted to PNG: after.png"
fi

echo ""
echo "🔍 STEP 7: Comparing Screenshots"
echo "================================"

# Compare files
if cmp -s ${SCREENSHOT_DIR}/before.xwd ${SCREENSHOT_DIR}/after.xwd; then
    echo "❌ IDENTICAL: Screenshots are identical - WebSocket pipeline NOT working"
    SCREENSHOTS_DIFFERENT=false
else
    echo "✅ DIFFERENT: Screenshots are different - WebSocket pipeline IS working!"
    SCREENSHOTS_DIFFERENT=true
fi

# Check file sizes
BEFORE_SIZE=$(stat -c%s ${SCREENSHOT_DIR}/before.xwd)
AFTER_SIZE=$(stat -c%s ${SCREENSHOT_DIR}/after.xwd)
echo "Before screenshot size: ${BEFORE_SIZE} bytes"
echo "After screenshot size: ${AFTER_SIZE} bytes"

echo ""
echo "📤 STEP 8: Uploading Results to S3"
echo "=================================="

# Upload screenshots
if [ -f ${SCREENSHOT_DIR}/before.png ]; then
    aws s3 cp ${SCREENSHOT_DIR}/before.png s3://speccytestscreenshots03082025/websocket_test_before.png
    echo "✅ Uploaded before.png"
fi

if [ -f ${SCREENSHOT_DIR}/after.png ]; then
    aws s3 cp ${SCREENSHOT_DIR}/after.png s3://speccytestscreenshots03082025/websocket_test_after.png
    echo "✅ Uploaded after.png"
fi

# Create comprehensive test results
cat > ${SCREENSHOT_DIR}/websocket_test_results.json << EOF
{
  "test_name": "WebSocket Pipeline Test",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "websocket_test_passed": $([ ${WEBSOCKET_TEST_RESULT} -eq 0 ] && echo "true" || echo "false"),
  "screenshots_different": ${SCREENSHOTS_DIFFERENT},
  "before_size": ${BEFORE_SIZE},
  "after_size": ${AFTER_SIZE},
  "key_sequence": "HELLO TEST",
  "pipeline": "WebSocket → Python Server → xdotool → FUSE",
  "conclusion": "$([ ${WEBSOCKET_TEST_RESULT} -eq 0 ] && [ "$SCREENSHOTS_DIFFERENT" = "true" ] && echo "Complete pipeline WORKS" || echo "Pipeline has issues")"
}
EOF

aws s3 cp ${SCREENSHOT_DIR}/websocket_test_results.json s3://speccytestscreenshots03082025/websocket_test_results.json
echo "✅ Uploaded test results"

echo ""
echo "🧹 STEP 9: Cleanup"
echo "=================="
kill ${SERVER_PID} ${FUSE_PID} ${XVFB_PID} 2>/dev/null || true
sleep 2

echo ""
echo "📋 FINAL RESULTS"
echo "==============="
echo "- WebSocket test: $([ ${WEBSOCKET_TEST_RESULT} -eq 0 ] && echo "✅ PASSED" || echo "❌ FAILED")"
echo "- Screenshots different: $([ "$SCREENSHOTS_DIFFERENT" = "true" ] && echo "✅ YES" || echo "❌ NO")"
echo "- Before size: ${BEFORE_SIZE} bytes"
echo "- After size: ${AFTER_SIZE} bytes"

if [ ${WEBSOCKET_TEST_RESULT} -eq 0 ] && [ "$SCREENSHOTS_DIFFERENT" = "true" ]; then
    echo ""
    echo "🎉 SUCCESS: Complete WebSocket pipeline is working!"
    echo "   ✅ WebSocket server accepts connections"
    echo "   ✅ Key commands are processed correctly"
    echo "   ✅ xdotool successfully injects keys"
    echo "   ✅ FUSE emulator responds to injected keys"
    echo "   ✅ Visual changes are detected in screenshots"
    echo ""
    echo "🚀 This confirms your AWS deployment method should work!"
elif [ ${WEBSOCKET_TEST_RESULT} -eq 0 ]; then
    echo ""
    echo "⚠️  PARTIAL SUCCESS: WebSocket works but no visual changes"
    echo "   ✅ WebSocket communication is working"
    echo "   ❌ Key injection may not be reaching the emulator"
    echo "   🔧 Check xdotool window targeting"
elif [ "$SCREENSHOTS_DIFFERENT" = "true" ]; then
    echo ""
    echo "⚠️  PARTIAL SUCCESS: Visual changes but WebSocket issues"
    echo "   ❌ WebSocket communication has problems"
    echo "   ✅ Key injection mechanism works (from previous test)"
    echo "   🔧 Check WebSocket server implementation"
else
    echo ""
    echo "❌ FAILURE: Neither WebSocket nor visual changes working"
    echo "   ❌ WebSocket communication failed"
    echo "   ❌ No visual changes detected"
    echo "   🔧 Check both WebSocket server and xdotool setup"
fi

echo ""
echo "🌐 View results online:"
echo "- Before: https://speccytestscreenshots03082025.s3.us-east-1.amazonaws.com/websocket_test_before.png"
echo "- After: https://speccytestscreenshots03082025.s3.us-east-1.amazonaws.com/websocket_test_after.png"
echo "- Results: https://speccytestscreenshots03082025.s3.us-east-1.amazonaws.com/websocket_test_results.json"
