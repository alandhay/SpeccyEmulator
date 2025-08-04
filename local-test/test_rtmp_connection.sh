#!/bin/bash

# Test RTMP Connection Without FFmpeg
echo "🔌 Testing RTMP Connection"
echo "=========================="

YOUTUBE_ENDPOINT="a.rtmp.youtube.com"
YOUTUBE_PORT="1935"
STREAM_KEY="v8s4-qp8m-xvw3-39z7-3dhm"

echo "Testing connection to: $YOUTUBE_ENDPOINT:$YOUTUBE_PORT"
echo ""

# Test 1: Basic ping
echo "1. Ping test..."
ping -c 3 $YOUTUBE_ENDPOINT

echo ""

# Test 2: Port connectivity
echo "2. Port connectivity test..."
timeout 10 bash -c "echo >/dev/tcp/$YOUTUBE_ENDPOINT/$YOUTUBE_PORT" && echo "✅ Port $YOUTUBE_PORT is reachable" || echo "❌ Port $YOUTUBE_PORT is NOT reachable"

echo ""

# Test 3: Telnet test
echo "3. Telnet test (will timeout after 5 seconds)..."
timeout 5 telnet $YOUTUBE_ENDPOINT $YOUTUBE_PORT 2>&1 | head -5

echo ""

# Test 4: Check local network interface
echo "4. Local network interface..."
ip route get 8.8.8.8 | head -1

echo ""

# Test 5: DNS resolution
echo "5. DNS resolution..."
nslookup $YOUTUBE_ENDPOINT | grep -A 2 "Name:"

echo ""
echo "🎯 Connection Test Results:"
echo "=========================="
echo "If ping works but port 1935 is not reachable:"
echo "  → Firewall/security group blocking outbound RTMP"
echo ""
echo "If nothing works:"
echo "  → Network connectivity issue from EC2"
echo ""
echo "If everything works:"
echo "  → Issue is with FFmpeg parameters or stream key"
