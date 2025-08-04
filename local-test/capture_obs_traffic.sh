#!/bin/bash

# Capture OBS Network Traffic for Analysis
echo "🔍 Capturing OBS Network Traffic"
echo "================================"

echo "1. Starting network capture..."
echo "This will capture all traffic to YouTube RTMP servers"
echo ""

# Start tcpdump to capture RTMP traffic
sudo tcpdump -i any -w obs_rtmp_capture.pcap host a.rtmp.youtube.com or host b.rtmp.youtube.com &
TCPDUMP_PID=$!

echo "Network capture started (PID: $TCPDUMP_PID)"
echo ""
echo "2. Now start your OBS stream for 30 seconds"
echo "============================================"
echo "- Open OBS"
echo "- Click 'Start Streaming'"
echo "- Let it run for 30 seconds"
echo "- Stop the stream"
echo "- Then press ENTER here to stop capture"
echo ""

read -p "Press ENTER after you've finished the OBS test..."

# Stop capture
sudo kill $TCPDUMP_PID 2>/dev/null
sleep 2

echo ""
echo "3. Analyzing captured traffic..."
echo "==============================="

if [ -f obs_rtmp_capture.pcap ]; then
    echo "✅ Capture file created: obs_rtmp_capture.pcap"
    echo "File size: $(ls -lh obs_rtmp_capture.pcap | awk '{print $5}')"
    
    # Basic analysis
    echo ""
    echo "RTMP connections found:"
    tcpdump -r obs_rtmp_capture.pcap -n | grep -E "(1935|rtmp)" | head -10
else
    echo "❌ No capture file created"
fi

echo ""
echo "4. Next: Run our FFmpeg test with same capture"
echo "=============================================="
