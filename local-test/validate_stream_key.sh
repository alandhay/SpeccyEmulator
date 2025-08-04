#!/bin/bash

# Validate YouTube Stream Key and Setup
echo "🔑 YouTube Stream Key Validation"
echo "==============================="

STREAM_KEY="0ebh-efdh-9qtq-2eq3-e6hz"

echo "Stream Key: $STREAM_KEY"
echo "Key Length: ${#STREAM_KEY} characters"
echo ""

# Check stream key format
if [[ ${#STREAM_KEY} -lt 10 ]]; then
    echo "⚠️  WARNING: Stream key seems too short (${#STREAM_KEY} chars)"
    echo "   YouTube stream keys are usually 20+ characters"
elif [[ ${#STREAM_KEY} -gt 50 ]]; then
    echo "⚠️  WARNING: Stream key seems too long (${#STREAM_KEY} chars)"
else
    echo "✅ Stream key length looks reasonable (${#STREAM_KEY} chars)"
fi

echo ""
echo "🔍 Testing RTMP endpoints:"
echo "========================="

# Test primary endpoint
echo "Testing primary: rtmp://a.rtmp.youtube.com/live2"
timeout 5 nc -zv a.rtmp.youtube.com 1935 2>&1 | head -1

# Test backup endpoint  
echo "Testing backup: rtmp://b.rtmp.youtube.com/live2"
timeout 5 nc -zv b.rtmp.youtube.com 1935 2>&1 | head -1

echo ""
echo "📋 YouTube Studio Checklist:"
echo "============================"
echo "Please verify these in YouTube Studio (https://studio.youtube.com):"
echo ""
echo "1. Go to 'Go Live' → 'Stream' tab"
echo "2. Check that your stream key matches: $STREAM_KEY"
echo "3. Verify stream settings:"
echo "   - Title: Set a stream title"
echo "   - Privacy: Set to 'Public' (not Unlisted/Private)"
echo "   - Category: Gaming (recommended)"
echo "4. Stream status should show 'Ready to stream'"
echo "5. After FFmpeg connects, click 'GO LIVE' button"
echo ""
echo "🚨 Common Issues:"
echo "================"
echo "- Stream key expired: Generate new key in YouTube Studio"
echo "- Account not verified: Need phone verification for live streaming"
echo "- Recent strikes: Account restrictions prevent live streaming"
echo "- Wrong stream key: Copy-paste error or old key"
echo ""
echo "Run this to test with detailed debugging:"
echo "./debug_youtube_stream.sh"
