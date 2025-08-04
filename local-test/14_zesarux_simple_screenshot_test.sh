#!/bin/bash
# ZEsarUX Simple Screenshot Test using built-in save-screen command
set -e

echo "🧪 EXPERIMENT 14: ZEsarUX Simple Screenshot Test"
echo "==============================================="
echo "GOAL: Use ZEsarUX's save-screen command to prove key input works"

ZESARUX_BIN="/home/ubuntu/workspace/SpeccyEmulator/local-test/zesarux/extracted/ZEsarUX-12.0/zesarux"
ZRCP_PORT=10000
SCREENSHOT_DIR="/tmp/zesarux_simple_screenshots"
S3_BUCKET="speccytestscreenshots03082025"

# Clean up and prepare
pkill -f zesarux 2>/dev/null || true
rm -rf ${SCREENSHOT_DIR}
mkdir -p ${SCREENSHOT_DIR}
sleep 2

echo "📁 Screenshot directory: ${SCREENSHOT_DIR}"
echo "🪣 S3 bucket: ${S3_BUCKET}"

echo ""
echo "🎮 Starting ZEsarUX in headless mode with ZRCP"
echo "=============================================="

${ZESARUX_BIN} --machine 48k --vo null --ao null --noconfigfile --nowelcomemessage \
    --enable-remoteprotocol --remoteprotocol-port ${ZRCP_PORT} >/dev/null 2>&1 &

ZESARUX_PID=$!
echo "✅ ZEsarUX started with PID: ${ZESARUX_PID}"

sleep 8

# Verify ZRCP is working
if ! echo "get-version" | timeout 3s nc localhost ${ZRCP_PORT} >/dev/null 2>&1; then
    echo "❌ ZRCP connection failed"
    kill ${ZESARUX_PID} 2>/dev/null || true
    exit 1
fi
echo "✅ ZRCP connection verified"

echo ""
echo "📸 STEP 1: Taking BEFORE screenshot"
echo "==================================="

# Wait for ZX Spectrum to fully boot
sleep 3

# Take before screenshot using ZRCP save-screen command
echo "save-screen ${SCREENSHOT_DIR}/before.bmp" | timeout 5s nc localhost ${ZRCP_PORT} >/dev/null
echo "✅ Before screenshot saved: before.bmp"

echo ""
echo "⌨️  STEP 2: Sending key input via ZRCP"
echo "======================================"

echo "Sending key sequence: 'HELLO WORLD'"
echo "send-keys-string HELLO WORLD" | timeout 5s nc localhost ${ZRCP_PORT} >/dev/null
echo "✅ Key sequence sent via ZRCP"

# Wait for the keys to be processed
sleep 3

echo ""
echo "📸 STEP 3: Taking AFTER screenshot"
echo "=================================="

# Take after screenshot
echo "save-screen ${SCREENSHOT_DIR}/after.bmp" | timeout 5s nc localhost ${ZRCP_PORT} >/dev/null
echo "✅ After screenshot saved: after.bmp"

echo ""
echo "🔍 STEP 4: Comparing screenshots"
echo "================================"

# Check if files exist
if [ ! -f ${SCREENSHOT_DIR}/before.bmp ] || [ ! -f ${SCREENSHOT_DIR}/after.bmp ]; then
    echo "❌ Screenshot files missing"
    ls -la ${SCREENSHOT_DIR}/
    kill ${ZESARUX_PID} 2>/dev/null || true
    exit 1
fi

# Compare the files
if cmp -s ${SCREENSHOT_DIR}/before.bmp ${SCREENSHOT_DIR}/after.bmp; then
    echo "❌ IDENTICAL: Screenshots are identical - key input may NOT be working"
    SCREENSHOTS_DIFFERENT=false
else
    echo "✅ DIFFERENT: Screenshots are different - key input IS working!"
    SCREENSHOTS_DIFFERENT=true
fi

# Check file sizes
BEFORE_SIZE=$(stat -c%s ${SCREENSHOT_DIR}/before.bmp)
AFTER_SIZE=$(stat -c%s ${SCREENSHOT_DIR}/after.bmp)
echo "Before screenshot size: ${BEFORE_SIZE} bytes"
echo "After screenshot size: ${AFTER_SIZE} bytes"

echo ""
echo "📤 STEP 5: Uploading to S3"
echo "=========================="

# Create S3 bucket if it doesn't exist
aws s3 mb s3://${S3_BUCKET} --region us-east-1 2>/dev/null || echo "Bucket may already exist"

# Upload screenshots
aws s3 cp ${SCREENSHOT_DIR}/before.bmp s3://${S3_BUCKET}/before.bmp --acl public-read
echo "✅ Uploaded before.bmp to S3"

aws s3 cp ${SCREENSHOT_DIR}/after.bmp s3://${S3_BUCKET}/after.bmp --acl public-read
echo "✅ Uploaded after.bmp to S3"

# Create a test results file
cat > ${SCREENSHOT_DIR}/test_results.json << EOF
{
  "test_name": "ZEsarUX Simple Screenshot Test",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "screenshots_different": ${SCREENSHOTS_DIFFERENT},
  "before_size": ${BEFORE_SIZE},
  "after_size": ${AFTER_SIZE},
  "key_sequence": "HELLO WORLD",
  "zesarux_version": "12.0",
  "test_method": "ZRCP save-screen command",
  "test_conclusion": "$([ "$SCREENSHOTS_DIFFERENT" = "true" ] && echo "Key input WORKS - ZEsarUX processes keys correctly" || echo "Key input may NOT work - No visual change detected")"
}
EOF

aws s3 cp ${SCREENSHOT_DIR}/test_results.json s3://${S3_BUCKET}/test_results.json --acl public-read
echo "✅ Uploaded test results to S3"

echo ""
echo "🧹 Cleaning up..."
kill ${ZESARUX_PID} 2>/dev/null || true
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
echo "- Before: https://${S3_BUCKET}.s3.us-east-1.amazonaws.com/before.bmp"
echo "- After: https://${S3_BUCKET}.s3.us-east-1.amazonaws.com/after.bmp"
echo "- Results: https://${S3_BUCKET}.s3.us-east-1.amazonaws.com/test_results.json"
