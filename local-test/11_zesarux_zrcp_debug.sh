#!/bin/bash
# ZEsarUX ZRCP Debug Test - Comprehensive debugging of remote protocol
set -e

echo "🧪 EXPERIMENT 11: ZEsarUX ZRCP Debug Test"
echo "=========================================="

ZESARUX_BIN="/home/ubuntu/workspace/SpeccyEmulator/local-test/zesarux/extracted/ZEsarUX-12.0/zesarux"
ZRCP_PORT=10000
LOG_FILE="/tmp/zesarux_debug.log"

# Clean up
pkill -f zesarux 2>/dev/null || true
rm -f ${LOG_FILE}
sleep 2

echo "✅ ZEsarUX binary: ${ZESARUX_BIN}"
echo "📝 Log file: ${LOG_FILE}"

echo ""
echo "🎮 Starting ZEsarUX with ZRCP and full logging"
echo "=============================================="

echo "Command: ${ZESARUX_BIN} --machine 48k --vo null --ao null --noconfigfile --nowelcomemessage --enable-remoteprotocol --remoteprotocol-port ${ZRCP_PORT} --verbose 4"

# Start ZEsarUX with full logging
${ZESARUX_BIN} --machine 48k --vo null --ao null --noconfigfile --nowelcomemessage \
    --enable-remoteprotocol --remoteprotocol-port ${ZRCP_PORT} --verbose 4 \
    > ${LOG_FILE} 2>&1 &

ZESARUX_PID=$!
echo "✅ ZEsarUX started with PID: ${ZESARUX_PID}"

echo ""
echo "⏱️  Waiting for ZEsarUX to initialize (10 seconds)..."
sleep 10

echo ""
echo "📊 Process Status:"
if ps -p ${ZESARUX_PID} > /dev/null 2>&1; then
    echo "✅ ZEsarUX process running (PID: ${ZESARUX_PID})"
    ps -p ${ZESARUX_PID} -o pid,cmd,%cpu,%mem
else
    echo "❌ ZEsarUX process not running"
    echo "📝 Checking log file for errors..."
    if [ -f ${LOG_FILE} ]; then
        echo "=== ZEsarUX Log Output ==="
        cat ${LOG_FILE}
    fi
    exit 1
fi

echo ""
echo "🔍 Network Status:"
echo "=================="
echo "Checking if ZRCP port ${ZRCP_PORT} is listening..."
if ss -tln | grep ${ZRCP_PORT}; then
    echo "✅ Port ${ZRCP_PORT} is listening"
else
    echo "❌ Port ${ZRCP_PORT} is not listening"
fi

echo ""
echo "All listening ports:"
ss -tln | head -10

echo ""
echo "📝 ZEsarUX Log Output (last 20 lines):"
echo "======================================"
if [ -f ${LOG_FILE} ]; then
    tail -20 ${LOG_FILE}
else
    echo "No log file found"
fi

echo ""
echo "🧪 Testing ZRCP Connection"
echo "=========================="

# Test 1: Simple connection test
echo "Test 1: Basic connection test..."
if timeout 3s bash -c "exec 3<>/dev/tcp/localhost/${ZRCP_PORT}" 2>/dev/null; then
    echo "✅ TCP connection successful"
else
    echo "❌ TCP connection failed"
fi

# Test 2: Netcat test
echo ""
echo "Test 2: Netcat connection test..."
if echo "help" | timeout 3s nc localhost ${ZRCP_PORT} 2>/dev/null; then
    echo "✅ Netcat connection successful"
else
    echo "❌ Netcat connection failed"
fi

# Test 3: Telnet test
echo ""
echo "Test 3: Telnet connection test..."
if timeout 3s telnet localhost ${ZRCP_PORT} 2>/dev/null; then
    echo "✅ Telnet connection successful"
else
    echo "❌ Telnet connection failed"
fi

echo ""
echo "🔍 Detailed Connection Analysis"
echo "==============================="

# Check if the port is actually bound to the process
echo "Checking process network connections:"
if command -v lsof >/dev/null 2>&1; then
    lsof -p ${ZESARUX_PID} -a -i 2>/dev/null || echo "lsof not available or no connections"
else
    echo "lsof not available"
fi

# Check with ss for the specific process
echo ""
echo "Checking socket details:"
ss -tlnp | grep ${ZRCP_PORT} || echo "No socket details found"

echo ""
echo "⏱️  Extended observation (5 seconds)..."
sleep 5

echo ""
echo "📝 Final Log Check (last 10 lines):"
echo "===================================="
if [ -f ${LOG_FILE} ]; then
    tail -10 ${LOG_FILE}
fi

echo ""
echo "🧹 Cleaning up..."
kill ${ZESARUX_PID} 2>/dev/null || true
sleep 2

echo ""
echo "✅ ZEsarUX ZRCP debug test complete!"
echo ""
echo "📋 RESULTS SUMMARY:"
echo "- ZEsarUX startup: $([ -n "$ZESARUX_PID" ] && echo "✅ SUCCESS" || echo "❌ FAILED")"
echo "- ZRCP port listening: $(ss -tln | grep -q ${ZRCP_PORT} && echo "✅ YES" || echo "❌ NO")"
echo "- Connection test: $(echo "help" | timeout 2s nc localhost ${ZRCP_PORT} >/dev/null 2>&1 && echo "✅ SUCCESS" || echo "❌ FAILED")"
echo ""
echo "📝 Log file preserved at: ${LOG_FILE}"
echo "   Use 'cat ${LOG_FILE}' to view full output"
