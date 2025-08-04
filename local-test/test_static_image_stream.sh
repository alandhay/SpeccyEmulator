#!/bin/bash

# Static Image YouTube Streaming Test
# Using the exact FFmpeg settings provided by user
echo "🖼️ Static Image YouTube Streaming Test"
echo "======================================"

STREAM_KEY="3gpw-mdh2-6vwy-txb8-ebam"
RTMP_URL="rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY"
IMAGE_FILE="../image.jpg"

echo "Stream Key: $STREAM_KEY"
echo "RTMP URL: $RTMP_URL"
echo "Image File: $IMAGE_FILE"
echo ""

# Verify image exists
if [ ! -f "$IMAGE_FILE" ]; then
    echo "❌ Error: Image file not found at $IMAGE_FILE"
    echo "Please run this script from the local-test directory"
    exit 1
fi

echo "✅ Image file found: $(file $IMAGE_FILE)"
echo ""

# Kill any existing FFmpeg processes
echo "🧹 Cleaning up existing processes..."
pkill -f ffmpeg 2>/dev/null || true
sleep 2

echo ""
echo "🚀 Starting static image stream with your exact settings..."
echo "========================================================="
echo ""
echo "FFmpeg Configuration:"
echo "- Input: Static image with loop and real-time reading"
echo "- Audio: Null source (stereo, 44.1kHz)"
echo "- Video Codec: libx264 with veryfast preset"
echo "- Video Tune: stillimage (optimized for static content)"
echo "- Audio Codec: AAC at 128k bitrate"
echo "- Pixel Format: yuv420p (YouTube compatible)"
echo "- Duration: Until shortest input ends"
echo "- Output Format: FLV for RTMP"
echo ""
echo "⏱️ Stream will run for approximately 60 seconds..."
echo "Check YouTube Studio: https://studio.youtube.com"
echo ""

# Your exact FFmpeg command
ffmpeg -loop 1 -re -i "$IMAGE_FILE" \
       -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 \
       -c:v libx264 \
       -preset veryfast \
       -tune stillimage \
       -c:a aac \
       -b:a 128k \
       -pix_fmt yuv420p \
       -shortest \
       -f flv \
       "$RTMP_URL" \
       -t 60 \
       -v info

echo ""
echo "✅ Static image stream completed!"
echo ""
echo "📊 Settings Comparison with Local Tests:"
echo "========================================"
echo "Your Settings vs Local Test Settings:"
echo ""
echo "INPUT:"
echo "  Yours: Static image loop (-loop 1 -re -i image.jpg)"
echo "  Local: X11 screen capture (-f x11grab -i :99.0+0,0)"
echo ""
echo "VIDEO ENCODING:"
echo "  Yours: -preset veryfast -tune stillimage"
echo "  Local: -preset fast (no tune)"
echo ""
echo "BITRATE:"
echo "  Yours: Default bitrate (no explicit setting)"
echo "  Local: -b:v 2500k -maxrate 2500k -bufsize 5000k"
echo ""
echo "AUDIO:"
echo "  Yours: AAC 128k with null source"
echo "  Local: No audio stream"
echo ""
echo "DURATION:"
echo "  Yours: -shortest (stops when inputs end)"
echo "  Local: -t 60 (explicit 60 seconds)"
echo ""
echo "🎯 Key Advantages of Your Approach:"
echo "- Optimized for static content (tune stillimage)"
echo "- Includes audio track (required by some platforms)"
echo "- Uses real-time reading (-re) for proper streaming pace"
echo "- More efficient for static images (no screen capture overhead)"
echo ""
echo "🎯 Key Advantages of Local Test Approach:"
echo "- Explicit bitrate control for consistent quality"
echo "- Optimized for live video content"
echo "- Lower CPU usage (no audio processing)"
echo "- Proven to work with YouTube Live"
echo ""
echo "💡 Recommendation:"
echo "Your settings are perfect for streaming static test patterns!"
echo "The 'tune stillimage' parameter is especially good for this use case."
