#!/bin/bash
# ZEsarUX Key Input Verification Test
# PROVE that key input actually affects the emulated ZX Spectrum

set -e

echo "🧪 EXPERIMENT 12: ZEsarUX Key Input Verification"
echo "==============================================="
echo "GOAL: Prove that ZRCP key commands actually affect the emulated ZX Spectrum"

ZESARUX_BIN="/home/ubuntu/workspace/SpeccyEmulator/local-test/zesarux/extracted/ZEsarUX-12.0/zesarux"
ZRCP_PORT=10000

# Clean up
pkill -f zesarux 2>/dev/null || true
sleep 2

echo ""
echo "🎮 Starting ZEsarUX with ZRCP enabled"
echo "===================================="

${ZESARUX_BIN} --machine 48k --vo null --ao null --noconfigfile --nowelcomemessage \
    --enable-remoteprotocol --remoteprotocol-port ${ZRCP_PORT} >/dev/null 2>&1 &

ZESARUX_PID=$!
echo "✅ ZEsarUX started with PID: ${ZESARUX_PID}"

sleep 5

# Verify ZRCP is working
if ! echo "get-version" | timeout 3s nc localhost ${ZRCP_PORT} >/dev/null 2>&1; then
    echo "❌ ZRCP connection failed"
    kill ${ZESARUX_PID} 2>/dev/null || true
    exit 1
fi

echo "✅ ZRCP connection verified"

echo ""
echo "🔍 TEST 1: Check Initial ZX Spectrum State"
echo "=========================================="

echo "Getting initial CPU registers..."
INITIAL_REGISTERS=$(echo "get-registers" | timeout 5s nc localhost ${ZRCP_PORT} | tail -n +4)
echo "Initial state captured"

echo ""
echo "🔍 TEST 2: Check Memory State Before Key Input"
echo "=============================================="

echo "Reading memory at address 23560 (LAST_K - last key pressed)..."
INITIAL_LASTK=$(echo "read-memory 23560 1" | timeout 5s nc localhost ${ZRCP_PORT} | grep -o '[0-9A-F][0-9A-F]' | head -1)
echo "Initial LAST_K value: ${INITIAL_LASTK}"

echo ""
echo "🔍 TEST 3: Send Key Input and Verify Change"
echo "==========================================="

echo "Sending key 'A' via ZRCP..."
echo "send-keys-string A" | timeout 5s nc localhost ${ZRCP_PORT} >/dev/null

sleep 1

echo "Reading LAST_K again to see if it changed..."
AFTER_LASTK=$(echo "read-memory 23560 1" | timeout 5s nc localhost ${ZRCP_PORT} | grep -o '[0-9A-F][0-9A-F]' | head -1)
echo "After key press LAST_K value: ${AFTER_LASTK}"

echo ""
echo "🔍 TEST 4: Check CPU State Changes"
echo "=================================="

echo "Getting CPU registers after key press..."
AFTER_REGISTERS=$(echo "get-registers" | timeout 5s nc localhost ${ZRCP_PORT} | tail -n +4)

echo ""
echo "🔍 TEST 5: Test Multiple Key Sequence"
echo "====================================="

echo "Sending key sequence 'HELLO' and checking for changes..."
echo "send-keys-string HELLO" | timeout 5s nc localhost ${ZRCP_PORT} >/dev/null

sleep 1

FINAL_LASTK=$(echo "read-memory 23560 1" | timeout 5s nc localhost ${ZRCP_PORT} | grep -o '[0-9A-F][0-9A-F]' | head -1)
echo "After 'HELLO' sequence LAST_K value: ${FINAL_LASTK}"

echo ""
echo "🔍 TEST 6: Check Keyboard Buffer"
echo "==============================="

echo "Reading keyboard buffer area (23552-23563)..."
KEYBOARD_BUFFER=$(echo "hexdump 23552 12" | timeout 5s nc localhost ${ZRCP_PORT} | tail -n +4)
echo "Keyboard buffer contents:"
echo "${KEYBOARD_BUFFER}"

echo ""
echo "🧹 Cleaning up..."
kill ${ZESARUX_PID} 2>/dev/null || true
sleep 2

echo ""
echo "📋 VERIFICATION RESULTS:"
echo "======================="
echo "- Initial LAST_K: ${INITIAL_LASTK}"
echo "- After 'A' key: ${AFTER_LASTK}"  
echo "- After 'HELLO': ${FINAL_LASTK}"
echo ""

if [ "${INITIAL_LASTK}" != "${AFTER_LASTK}" ] || [ "${AFTER_LASTK}" != "${FINAL_LASTK}" ]; then
    echo "✅ SUCCESS: Memory values changed - Key input IS affecting the emulated ZX Spectrum!"
    echo "   This proves ZRCP key commands actually work."
else
    echo "❌ FAILURE: Memory values unchanged - Key input may NOT be working"
    echo "   ZRCP accepts commands but they may not affect the emulation."
fi

echo ""
echo "📋 WHAT THIS PROVES:"
echo "- Whether ZRCP key commands actually reach the ZX Spectrum emulation"
echo "- Whether the emulated machine responds to injected key presses"
echo "- Whether ZEsarUX is a viable replacement for FUSE input handling"
