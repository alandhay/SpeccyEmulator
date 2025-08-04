#!/bin/bash
# ZEsarUX Screenshot Test - Visual proof of key input functionality
set -e

echo "🧪 EXPERIMENT 13: ZEsarUX Screenshot Verification Test"
echo "====================================================="
echo "GOAL: Take before/after screenshots to prove key input actually works"

ZESARUX_BIN="/home/ubuntu/workspace/SpeccyEmulator/local-test/zesarux/extracted/ZEsarUX-12.0/zesarux"
ZRCP_PORT=10000
SCREENSHOT_DIR="/tmp/zesarux_screenshots"
S3_BUCKET="speccytestscreenshots03082025"

# Clean up and prepare
pkill -f zesarux 2>/dev/null || true
rm -rf ${SCREENSHOT_DIR}
mkdir -p ${SCREENSHOT_DIR}
sleep 2

echo "📁 Screenshot directory: ${SCREENSHOT_DIR}"
echo "🪣 S3 bucket: ${S3_BUCKET}"

echo ""
echo "🎮 Starting ZEsarUX with X11 display for screenshots"
echo "=================================================="

# We need X11 for screenshots, so let's start Xvfb
DISPLAY_NUM=99
export DISPLAY=:${DISPLAY_NUM}

echo "📺 Starting Xvfb for screenshot capture..."
Xvfb :${DISPLAY_NUM} -screen 0 320x240x24 -ac &
XVFB_PID=$!
echo "✅ Xvfb started with PID: ${XVFB_PID}"

sleep 3

echo "🎮 Starting ZEsarUX with both X11 display and ZRCP..."
${ZESARUX_BIN} --machine 48k --zoom 1 --noconfigfile --nowelcomemessage \
    --enable-remoteprotocol --remoteprotocol-port ${ZRCP_PORT} &

ZESARUX_PID=$!
echo "✅ ZEsarUX started with PID: ${ZESARUX_PID}"

sleep 5

# Verify both X11 window and ZRCP are working
echo ""
echo "🔍 Verifying ZEsarUX is ready..."

# Check if ZEsarUX window exists
ZESARUX_WINDOW=$(xdotool search --name "ZEsarUX" 2>/dev/null | head -1 || echo "")
if [ -z "$ZESARUX_WINDOW" ]; then
    echo "❌ ZEsarUX window not found"
    kill ${ZESARUX_PID} ${XVFB_PID} 2>/dev/null || true
    exit 1
fi
echo "✅ ZEsarUX window found: ${ZESARUX_WINDOW}"

# Check if ZRCP is responding
if ! echo "get-version" | timeout 3s nc localhost ${ZRCP_PORT} >/dev/null 2>&1; then
    echo "❌ ZRCP connection failed"
    kill ${ZESARUX_PID} ${XVFB_PID} 2>/dev/null || true
    exit 1
fi
echo "✅ ZRCP connection verified"

echo ""
echo "📸 STEP 1: Taking BEFORE screenshot"
echo "==================================="

# Wait for ZX Spectrum to fully boot
sleep 3

# Take before screenshot using xwd
xwd -display :${DISPLAY_NUM} -id ${ZESARUX_WINDOW} -out ${SCREENSHOT_DIR}/before.xwd
echo "✅ Before screenshot captured: before.xwd"

# Convert to PNG for easier viewing
if command -v convert >/dev/null 2>&1; then
    convert ${SCREENSHOT_DIR}/before.xwd ${SCREENSHOT_DIR}/before.png
    echo "✅ Converted to PNG: before.png"
else
    echo "⚠️  ImageMagick not available, keeping XWD format"
fi

echo ""
echo "⌨️  STEP 2: Sending key input via ZRCP"
echo "======================================"

echo "Sending key sequence: 'HELLO WORLD'"
echo "send-keys-string HELLO WORLD" | timeout 5s nc localhost ${ZRCP_PORT} >/dev/null
echo "✅ Key sequence sent via ZRCP"

# Wait for the keys to be processed
sleep 2

echo ""
echo "📸 STEP 3: Taking AFTER screenshot"
echo "=================================="

# Take after screenshot
xwd -display :${DISPLAY_NUM} -id ${ZESARUX_WINDOW} -out ${SCREENSHOT_DIR}/after.xwd
echo "✅ After screenshot captured: after.xwd"

# Convert to PNG
if command -v convert >/dev/null 2>&1; then
    convert ${SCREENSHOT_DIR}/after.xwd ${SCREENSHOT_DIR}/after.png
    echo "✅ Converted to PNG: after.png"
fi

echo ""
echo "🔍 STEP 4: Comparing screenshots"
echo "================================"

# Compare the files
if cmp -s ${SCREENSHOT_DIR}/before.xwd ${SCREENSHOT_DIR}/after.xwd; then
    echo "❌ IDENTICAL: Screenshots are identical - key input may NOT be working"
    SCREENSHOTS_DIFFERENT=false
else
    echo "✅ DIFFERENT: Screenshots are different - key input IS working!"
    SCREENSHOTS_DIFFERENT=true
fi

# Also check file sizes as a quick indicator
BEFORE_SIZE=$(stat -c%s ${SCREENSHOT_DIR}/before.xwd)
AFTER_SIZE=$(stat -c%s ${SCREENSHOT_DIR}/after.xwd)
echo "Before screenshot size: ${BEFORE_SIZE} bytes"
echo "After screenshot size: ${AFTER_SIZE} bytes"

echo ""
echo "📤 STEP 5: Uploading to S3"
echo "=========================="

# Create S3 bucket if it doesn't exist
aws s3 mb s3://${S3_BUCKET} --region us-east-1 2>/dev/null || echo "Bucket may already exist"

# Upload screenshots
if [ -f ${SCREENSHOT_DIR}/before.png ]; then
    aws s3 cp ${SCREENSHOT_DIR}/before.png s3://${S3_BUCKET}/before.png --acl public-read
    echo "✅ Uploaded before.png to S3"
else
    aws s3 cp ${SCREENSHOT_DIR}/before.xwd s3://${S3_BUCKET}/before.xwd --acl public-read
    echo "✅ Uploaded before.xwd to S3"
fi

if [ -f ${SCREENSHOT_DIR}/after.png ]; then
    aws s3 cp ${SCREENSHOT_DIR}/after.png s3://${S3_BUCKET}/after.png --acl public-read
    echo "✅ Uploaded after.png to S3"
else
    aws s3 cp ${SCREENSHOT_DIR}/after.xwd s3://${S3_BUCKET}/after.xwd --acl public-read
    echo "✅ Uploaded after.xwd to S3"
fi

# Create a test results file
cat > ${SCREENSHOT_DIR}/test_results.json << EOF
{
  "test_name": "ZEsarUX Key Input Screenshot Test",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "screenshots_different": ${SCREENSHOTS_DIFFERENT},
  "before_size": ${BEFORE_SIZE},
  "after_size": ${AFTER_SIZE},
  "key_sequence": "HELLO WORLD",
  "zesarux_version": "12.0",
  "test_conclusion": "$([ "$SCREENSHOTS_DIFFERENT" = "true" ] && echo "Key input WORKS" || echo "Key input may NOT work")"
}
EOF

aws s3 cp ${SCREENSHOT_DIR}/test_results.json s3://${S3_BUCKET}/test_results.json --acl public-read
echo "✅ Uploaded test results to S3"

echo ""
echo "🧹 Cleaning up..."
kill ${ZESARUX_PID} ${XVFB_PID} 2>/dev/null || true
sleep 2

echo ""
echo "📋 FINAL RESULTS:"
echo "================"
echo "- Screenshots different: ${SCREENSHOTS_DIFFERENT}"
echo "- Before size: ${BEFORE_SIZE} bytes"
echo "- After size: ${AFTER_SIZE} bytes"
echo "- S3 bucket: s3://${S3_BUCKET}/"
echo "- Test conclusion: $([ "$SCREENSHOTS_DIFFERENT" = "true" ] && echo "✅ Key input WORKS!" || echo "❌ Key input may NOT work")"
echo ""
echo "🌐 S3 URLs:"
echo "- Before: https://${S3_BUCKET}.s3.us-east-1.amazonaws.com/before.png"
echo "- After: https://${S3_BUCKET}.s3.us-east-1.amazonaws.com/after.png"
echo "- Results: https://${S3_BUCKET}.s3.us-east-1.amazonaws.com/test_results.json"
