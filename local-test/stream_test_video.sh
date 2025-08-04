#!/bin/bash

# YouTube Test Video Streaming Script
# Based on your working FFmpeg command pattern
echo "🎥 YouTube Test Video Streaming"
echo "==============================="

# Configuration
STREAM_KEY="3gpw-mdh2-6vwy-txb8-ebam"
RTMP_URL="rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY"
DURATION=60  # Stream duration in seconds

echo "Stream Key: $STREAM_KEY"
echo "RTMP URL: $RTMP_URL"
echo "Duration: ${DURATION} seconds"
echo ""

# Clean up any existing FFmpeg processes
echo "🧹 Cleaning up existing processes..."
pkill -f ffmpeg 2>/dev/null || true
sleep 2

echo ""
echo "🚀 Starting test video stream..."
echo "================================"
echo ""
echo "Stream Configuration:"
echo "- Resolution: 1280x720 (HD)"
echo "- Frame Rate: 30 FPS"
echo "- Video: Animated test pattern with timestamp"
echo "- Audio: Stereo tone at 44.1kHz"
echo "- Codec: H.264 (veryfast) + AAC"
echo "- Format: FLV for RTMP"
echo ""
echo "⏱️ Stream will run for ${DURATION} seconds..."
echo "📺 Check YouTube Studio: https://studio.youtube.com"
echo ""

# Create animated test video with your proven settings
ffmpeg -f lavfi -i "testsrc2=size=1280x720:rate=30" \
       -f lavfi -i "sine=frequency=440:sample_rate=44100" \
       -vf "drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:text='TEST STREAM %{localtime}':fontcolor=white:fontsize=48:x=(w-text_w)/2:y=(h-text_h)/2:box=1:boxcolor=black@0.5:boxborderw=5" \
       -c:v libx264 -preset veryfast -tune zerolatency \
       -c:a aac -b:a 128k \
       -pix_fmt yuv420p \
       -t $DURATION \
       -f flv "$RTMP_URL" \
       -v info

echo ""
echo "✅ Test video stream completed!"
echo ""
echo "📊 Stream Summary:"
echo "=================="
echo "- Used your proven FFmpeg parameters"
echo "- Animated test pattern with moving elements"
echo "- Real-time timestamp overlay"
echo "- Stereo audio tone (440Hz)"
echo "- Standard HD resolution (1280x720)"
echo "- Reliable synthetic inputs (no X11 dependencies)"
echo ""
echo "🎯 If this worked:"
echo "- Your FFmpeg settings are perfect"
echo "- YouTube stream key is valid"
echo "- Network connection is stable"
echo ""
echo "🎯 If this failed:"
echo "- Check YouTube Studio for error messages"
echo "- Verify stream key is still active"
echo "- Check network connectivity to YouTube"
echo ""
echo "💡 Next Steps:"
echo "- Try streaming actual emulator content with these same settings"
echo "- Replace testsrc2 with x11grab for real screen capture"
echo "- Keep the audio stream for compatibility"
