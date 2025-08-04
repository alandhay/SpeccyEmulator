#!/bin/bash

# Complete Streaming Process Cleanup Script
echo "🛑 Killing All Streaming Processes"
echo "=================================="

echo "1. Checking current FFmpeg processes..."
FFMPEG_COUNT=$(ps aux | grep ffmpeg | grep -v grep | wc -l)
echo "Found $FFMPEG_COUNT FFmpeg processes"

if [ $FFMPEG_COUNT -gt 0 ]; then
    echo "Current FFmpeg processes:"
    ps aux | grep ffmpeg | grep -v grep
    echo ""
fi

echo "2. Killing all FFmpeg processes..."
pkill -f ffmpeg 2>/dev/null && echo "✅ FFmpeg processes killed" || echo "ℹ️  No FFmpeg processes to kill"

echo "3. Killing Xvfb processes..."
pkill -f "Xvfb :99" 2>/dev/null && echo "✅ Xvfb processes killed" || echo "ℹ️  No Xvfb processes to kill"

echo "4. Killing any remaining streaming processes..."
pkill -f "x11grab" 2>/dev/null && echo "✅ x11grab processes killed" || echo "ℹ️  No x11grab processes to kill"
pkill -f "rtmp" 2>/dev/null && echo "✅ RTMP processes killed" || echo "ℹ️  No RTMP processes to kill"

echo ""
echo "5. Waiting for processes to terminate..."
sleep 2

echo "6. Force killing any stubborn processes..."
pkill -9 -f ffmpeg 2>/dev/null && echo "✅ Force killed FFmpeg" || echo "ℹ️  No FFmpeg to force kill"
pkill -9 -f "Xvfb :99" 2>/dev/null && echo "✅ Force killed Xvfb" || echo "ℹ️  No Xvfb to force kill"

echo ""
echo "7. Final verification..."
REMAINING_FFMPEG=$(ps aux | grep ffmpeg | grep -v grep | wc -l)
REMAINING_XVFB=$(ps aux | grep "Xvfb :99" | grep -v grep | wc -l)

echo "Remaining FFmpeg processes: $REMAINING_FFMPEG"
echo "Remaining Xvfb processes: $REMAINING_XVFB"

if [ $REMAINING_FFMPEG -eq 0 ] && [ $REMAINING_XVFB -eq 0 ]; then
    echo ""
    echo "✅ All streaming processes successfully terminated!"
else
    echo ""
    echo "⚠️  Some processes may still be running:"
    ps aux | grep -E "(ffmpeg|Xvfb :99)" | grep -v grep
fi

echo ""
echo "🧹 Cleanup completed!"
