#!/bin/bash

# YouTube Video File Streaming Script
# Based on your working FFmpeg command pattern
echo "🎬 YouTube Video File Streaming"
echo "==============================="

# Configuration
STREAM_KEY="3gpw-mdh2-6vwy-txb8-ebam"
RTMP_URL="rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY"
VIDEO_FILE="${1:-test_pattern.mp4}"  # Use command line argument or default

echo "Stream Key: $STREAM_KEY"
echo "RTMP URL: $RTMP_URL"
echo "Video File: $VIDEO_FILE"
echo ""

# Check if video file exists
if [ ! -f "$VIDEO_FILE" ]; then
    echo "❌ Error: Video file '$VIDEO_FILE' not found!"
    echo ""
    echo "Usage: $0 [video_file.mp4]"
    echo ""
    echo "Available video files in current directory:"
    ls -la *.mp4 *.avi *.mkv *.mov 2>/dev/null || echo "  No video files found"
    echo ""
    echo "💡 To create a test video file, run:"
    echo "   ffmpeg -f lavfi -i testsrc2=size=1280x720:rate=30 -f lavfi -i sine=frequency=440 -t 30 -c:v libx264 -c:a aac test_video.mp4"
    exit 1
fi

# Get video info
echo "📹 Video File Information:"
echo "=========================="
ffprobe -v quiet -print_format json -show_format -show_streams "$VIDEO_FILE" | jq -r '
.format | "Duration: \(.duration)s, Size: \(.size) bytes, Format: \(.format_name)",
.streams[] | select(.codec_type=="video") | "Video: \(.codec_name) \(.width)x\(.height) @ \(.r_frame_rate) fps",
.streams[] | select(.codec_type=="audio") | "Audio: \(.codec_name) \(.channels) channels @ \(.sample_rate)Hz"
' 2>/dev/null || {
    echo "Basic file info:"
    ls -lh "$VIDEO_FILE"
}
echo ""

# Clean up any existing FFmpeg processes
echo "🧹 Cleaning up existing processes..."
pkill -f ffmpeg 2>/dev/null || true
sleep 2

echo ""
echo "🚀 Starting video file stream..."
echo "================================"
echo ""
echo "Stream Configuration:"
echo "- Input: $VIDEO_FILE"
echo "- Real-time playback (-re flag)"
echo "- Video: Re-encode with your proven settings"
echo "- Audio: Re-encode to AAC 128k"
echo "- Output: 1280x720 HD (scaled if needed)"
echo "- Format: FLV for RTMP"
echo ""
echo "📺 Check YouTube Studio: https://studio.youtube.com"
echo ""

# Stream video file with your proven settings
# Re-encode to ensure compatibility and apply your working parameters
ffmpeg -re -i "$VIDEO_FILE" \
       -vf "scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2:black,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:text='LIVE STREAM %{localtime}':fontcolor=white:fontsize=32:x=10:y=10:box=1:boxcolor=black@0.7:boxborderw=3" \
       -c:v libx264 -preset veryfast -tune zerolatency \
       -c:a aac -b:a 128k -ar 44100 -ac 2 \
       -pix_fmt yuv420p \
       -f flv "$RTMP_URL" \
       -v info

echo ""
echo "✅ Video file stream completed!"
echo ""
echo "📊 Stream Features:"
echo "=================="
echo "- Used your proven FFmpeg parameters"
echo "- Scaled video to HD 1280x720 with letterboxing"
echo "- Added live timestamp overlay"
echo "- Re-encoded audio to stereo AAC 44.1kHz"
echo "- Real-time playback for proper streaming pace"
echo ""
echo "🎯 Key Advantages:"
echo "- Maintains aspect ratio with black bars if needed"
echo "- Ensures audio compatibility (stereo AAC)"
echo "- Uses your working codec settings"
echo "- Adds visual confirmation it's a live stream"
echo ""
echo "💡 To loop the video continuously:"
echo "   Add -stream_loop -1 before -i \"$VIDEO_FILE\""
