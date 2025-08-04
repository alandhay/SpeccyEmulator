#!/bin/bash
# Simple Key Injection Test - Focus on core mechanism
set -e

echo "🔑 SIMPLE KEY INJECTION TEST"
echo "============================"
echo "GOAL: Test xdotool key injection with visual proof"

# Configuration
DISPLAY_NUM=99
export DISPLAY=:${DISPLAY_NUM}
SCREENSHOT_DIR="/tmp/simple_key_test"

# Clean up
echo "🧹 Cleaning up..."
pkill -f "fuse-sdl" 2>/dev/null || true
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
# Start FUSE without the problematic scaler option
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
echo "📸 STEP 3: Taking BEFORE Screenshot"
echo "==================================="
sleep 3  # Wait for ZX Spectrum to boot

xwd -display :${DISPLAY_NUM} -id ${FUSE_WINDOW} -out ${SCREENSHOT_DIR}/before.xwd
echo "✅ Before screenshot captured"

if command -v convert >/dev/null 2>&1; then
    convert ${SCREENSHOT_DIR}/before.xwd ${SCREENSHOT_DIR}/before.png
    echo "✅ Converted to PNG: before.png"
fi

echo ""
echo "⌨️  STEP 4: Injecting Keys via xdotool"
echo "======================================"

# Focus the window first
echo "Focusing FUSE window..."
xdotool windowfocus ${FUSE_WINDOW}
sleep 1

# Send a simple test sequence
echo "Sending 'HELLO WORLD' sequence..."
for char in h e l l o space w o r l d; do
    echo "  Sending: $char"
    if [ "$char" = "space" ]; then
        xdotool key space
    else
        xdotool key $char
    fi
    sleep 0.3
done

echo "✅ Key sequence sent"
sleep 2

echo ""
echo "📸 STEP 5: Taking AFTER Screenshot"
echo "=================================="

xwd -display :${DISPLAY_NUM} -id ${FUSE_WINDOW} -out ${SCREENSHOT_DIR}/after.xwd
echo "✅ After screenshot captured"

if command -v convert >/dev/null 2>&1; then
    convert ${SCREENSHOT_DIR}/after.xwd ${SCREENSHOT_DIR}/after.png
    echo "✅ Converted to PNG: after.png"
fi

echo ""
echo "🔍 STEP 6: Comparing Screenshots"
echo "================================"

# Compare files
if cmp -s ${SCREENSHOT_DIR}/before.xwd ${SCREENSHOT_DIR}/after.xwd; then
    echo "❌ IDENTICAL: Screenshots are identical - key input NOT working"
    SCREENSHOTS_DIFFERENT=false
else
    echo "✅ DIFFERENT: Screenshots are different - key input IS working!"
    SCREENSHOTS_DIFFERENT=true
fi

# Check file sizes
BEFORE_SIZE=$(stat -c%s ${SCREENSHOT_DIR}/before.xwd)
AFTER_SIZE=$(stat -c%s ${SCREENSHOT_DIR}/after.xwd)
echo "Before screenshot size: ${BEFORE_SIZE} bytes"
echo "After screenshot size: ${AFTER_SIZE} bytes"

echo ""
echo "📤 STEP 7: Uploading Screenshots to S3"
echo "======================================"

# Upload both screenshots
if [ -f ${SCREENSHOT_DIR}/before.png ]; then
    aws s3 cp ${SCREENSHOT_DIR}/before.png s3://speccytestscreenshots03082025/simple_test_before.png
    echo "✅ Uploaded before.png"
    echo "🌐 View at: https://speccytestscreenshots03082025.s3.us-east-1.amazonaws.com/simple_test_before.png"
fi

if [ -f ${SCREENSHOT_DIR}/after.png ]; then
    aws s3 cp ${SCREENSHOT_DIR}/after.png s3://speccytestscreenshots03082025/simple_test_after.png
    echo "✅ Uploaded after.png"
    echo "🌐 View at: https://speccytestscreenshots03082025.s3.us-east-1.amazonaws.com/simple_test_after.png"
fi

# Create test results
cat > ${SCREENSHOT_DIR}/test_results.json << EOF
{
  "test_name": "Simple Key Injection Test",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "screenshots_different": ${SCREENSHOTS_DIFFERENT},
  "before_size": ${BEFORE_SIZE},
  "after_size": ${AFTER_SIZE},
  "key_sequence": "hello world",
  "emulator": "FUSE SDL",
  "method": "xdotool direct injection",
  "conclusion": "$([ "$SCREENSHOTS_DIFFERENT" = "true" ] && echo "Key injection WORKS" || echo "Key injection FAILED")"
}
EOF

aws s3 cp ${SCREENSHOT_DIR}/test_results.json s3://speccytestscreenshots03082025/simple_test_results.json
echo "✅ Uploaded test results"

echo ""
echo "🧹 STEP 8: Cleanup"
echo "=================="
kill ${FUSE_PID} ${XVFB_PID} 2>/dev/null || true
sleep 2

echo ""
echo "📋 FINAL RESULTS"
echo "==============="
echo "- Screenshots different: $([ "$SCREENSHOTS_DIFFERENT" = "true" ] && echo "✅ YES" || echo "❌ NO")"
echo "- Before size: ${BEFORE_SIZE} bytes"
echo "- After size: ${AFTER_SIZE} bytes"
echo "- Conclusion: $([ "$SCREENSHOTS_DIFFERENT" = "true" ] && echo "✅ Key injection WORKS!" || echo "❌ Key injection FAILED")"
echo ""
echo "🌐 View screenshots online:"
echo "- Before: https://speccytestscreenshots03082025.s3.us-east-1.amazonaws.com/simple_test_before.png"
echo "- After: https://speccytestscreenshots03082025.s3.us-east-1.amazonaws.com/simple_test_after.png"
echo "- Results: https://speccytestscreenshots03082025.s3.us-east-1.amazonaws.com/simple_test_results.json"
