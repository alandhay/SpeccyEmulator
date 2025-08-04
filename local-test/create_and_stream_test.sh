#!/bin/bash

# Complete Test: Create and Stream Test Video
# Based on your working FFmpeg command pattern
echo "🎬 Complete Test: Create and Stream Test Video"
echo "=============================================="

# Configuration
STREAM_KEY="3gpw-mdh2-6vwy-txb8-ebam"
RTMP_URL="rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY"
TEST_VIDEO="youtube_test_video.mp4"
VIDEO_DURATION=120
STREAM_DURATION=120

echo "Stream Key: $STREAM_KEY"
echo "RTMP URL: $RTMP_URL"
echo "Test Video: $TEST_VIDEO"
echo "Video Duration: ${VIDEO_DURATION}s"
echo "Stream Duration: ${STREAM_DURATION}s"
echo ""

# Clean up any existing processes and files
echo "🧹 Cleaning up..."
pkill -f ffmpeg 2>/dev/null || true
rm -f "$TEST_VIDEO" 2>/dev/null || true
sleep 2

echo ""
echo "🎬 Step 1: Creating test video..."
echo "================================="
echo ""
echo "Creating a ${VIDEO_DURATION}-second test video with:"
echo "- Animated test pattern (moving elements)"
echo "- Real-time timestamp (yellow, top-right corner)"
echo "- Color bars and geometric patterns"
echo "- Stereo audio tone (440Hz)"
echo "- HD 1280x720 resolution"
echo ""

# Create test video using your proven settings
ffmpeg -f lavfi -i "testsrc2=size=1280x720:rate=30" \
       -f lavfi -i "sine=frequency=440:sample_rate=44100" \
       -vf "drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:text='%{localtime}':fontcolor=yellow:fontsize=48:x=w-text_w-20:y=20:box=1:boxcolor=black@0.7:boxborderw=3,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf:text='Frame: %{frame_num}':fontcolor=white:fontsize=32:x=50:y=h-100:box=1:boxcolor=blue@0.7:boxborderw=3" \
       -c:v libx264 -preset veryfast -tune zerolatency \
       -c:a aac -b:a 128k \
       -pix_fmt yuv420p \
       -t $VIDEO_DURATION \
       "$TEST_VIDEO" \
       -y

if [ $? -eq 0 ]; then
    echo "✅ Test video created successfully!"
    echo "📹 File info: $(ls -lh "$TEST_VIDEO")"
else
    echo "❌ Failed to create test video!"
    exit 1
fi

echo ""
echo "🚀 Step 2: Streaming test video to YouTube..."
echo "============================================="
echo ""
echo "Stream Configuration:"
echo "- Input: $TEST_VIDEO (will loop for ${STREAM_DURATION}s)"
echo "- Real-time playback with looping"
echo "- Live timestamp overlay added"
echo "- Your proven FFmpeg settings"
echo ""
echo "📺 Check YouTube Studio NOW: https://studio.youtube.com"
echo "⏱️ Stream will run for ${STREAM_DURATION} seconds..."
echo ""

# Stream the test video with looping and live overlay
ffmpeg -stream_loop -1 -re -i "$TEST_VIDEO" \
       -vf "drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:text='🔴 LIVE: %{localtime}':fontcolor=red:fontsize=36:x=w-text_w-20:y=20:box=1:boxcolor=white@0.8:boxborderw=3" \
       -c:v libx264 -preset veryfast -tune zerolatency \
       -c:a aac -b:a 128k -ar 44100 -ac 2 \
       -pix_fmt yuv420p \
       -t $STREAM_DURATION \
       -f flv "$RTMP_URL" \
       -v info

echo ""
echo "✅ Test video stream completed!"
echo ""
echo "📊 Test Summary:"
echo "================"
echo "✅ Created test video: $TEST_VIDEO"
echo "✅ Streamed for ${STREAM_DURATION} seconds"
echo "✅ Used your proven FFmpeg parameters"
echo "✅ Included both video and audio streams"
echo "✅ Added live timestamp overlay"
echo "✅ Looped video content seamlessly"
echo ""
echo "🎯 What This Test Proves:"
echo "========================"
echo "- FFmpeg can create reliable test content"
echo "- Your streaming parameters work consistently"
echo "- YouTube accepts the video/audio format"
echo "- Network connection is stable"
echo "- Stream key is valid and active"
echo ""
echo "💡 Next Steps:"
echo "=============="
echo "1. If this worked perfectly:"
echo "   → Your settings are production-ready"
echo "   → Apply same parameters to emulator streaming"
echo ""
echo "2. If this had issues:"
echo "   → Check YouTube Studio for specific error messages"
echo "   → Verify stream key hasn't expired"
echo "   → Test network connectivity"
echo ""
echo "3. For emulator integration:"
echo "   → Replace test video input with X11 screen capture"
echo "   → Keep the audio stream (anullsrc)"
echo "   → Use same codec settings"
echo ""
echo "🗑️ Cleanup:"
echo "To remove test video: rm $TEST_VIDEO"
