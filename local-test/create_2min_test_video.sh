#!/bin/bash

# Create 2-Minute Test Video with Yellow Timestamp
# Based on your working FFmpeg command pattern
echo "🎬 Creating 2-Minute Test Video"
echo "==============================="

# Configuration
TEST_VIDEO="test_video_2min.mp4"
VIDEO_DURATION=120  # 2 minutes

echo "Output File: $TEST_VIDEO"
echo "Duration: ${VIDEO_DURATION} seconds (2 minutes)"
echo ""

# Clean up existing file
rm -f "$TEST_VIDEO" 2>/dev/null || true

echo "🎬 Creating test video with:"
echo "- Animated test pattern (testsrc2)"
echo "- Yellow timestamp in top-right corner"
echo "- Frame counter in bottom-left"
echo "- Stereo audio tone (440Hz)"
echo "- HD 1280x720 resolution"
echo "- 2-minute duration"
echo ""

# Create 2-minute test video with yellow timestamp in top right
ffmpeg -f lavfi -i "testsrc2=size=1280x720:rate=30" \
       -f lavfi -i "sine=frequency=440:sample_rate=44100" \
       -vf "drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:text='%{localtime}':fontcolor=yellow:fontsize=48:x=w-text_w-20:y=20:box=1:boxcolor=black@0.7:boxborderw=3,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf:text='Frame: %{frame_num}':fontcolor=white:fontsize=32:x=20:y=h-60:box=1:boxcolor=blue@0.7:boxborderw=3" \
       -c:v libx264 -preset veryfast -tune zerolatency \
       -c:a aac -b:a 128k \
       -pix_fmt yuv420p \
       -t $VIDEO_DURATION \
       "$TEST_VIDEO" \
       -y \
       -v info

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 2-minute test video created successfully!"
    echo "📹 File info: $(ls -lh "$TEST_VIDEO")"
    echo ""
    echo "📊 Video Details:"
    echo "================"
    echo "- Duration: 2 minutes (120 seconds)"
    echo "- Resolution: 1280x720 HD"
    echo "- Frame Rate: 30 FPS"
    echo "- Video Codec: H.264 (libx264)"
    echo "- Audio Codec: AAC 128k"
    echo "- Timestamp: Yellow text, top-right corner"
    echo "- Frame Counter: White text, bottom-left corner"
    echo ""
    echo "🎯 To stream this video to YouTube:"
    echo "   ./stream_video_file.sh $TEST_VIDEO"
    echo ""
    echo "🎯 To play locally:"
    echo "   ffplay $TEST_VIDEO"
    echo ""
    echo "🎯 To get detailed info:"
    echo "   ffprobe -v quiet -print_format json -show_format -show_streams $TEST_VIDEO"
else
    echo ""
    echo "❌ Failed to create test video!"
    echo "Check FFmpeg installation and font availability."
    exit 1
fi
