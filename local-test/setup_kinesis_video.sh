#!/bin/bash

# Setup Kinesis Video Streams for RTMP Streaming
echo "📹 Setting up Kinesis Video Streams"
echo "==================================="

STREAM_NAME="spectrum-emulator-stream"
REGION="us-east-1"

echo "Stream Name: $STREAM_NAME"
echo "Region: $REGION"
echo ""

# 1. Create Kinesis Video Stream
echo "1. Creating Kinesis Video Stream..."
aws kinesisvideo create-stream \
    --stream-name "$STREAM_NAME" \
    --data-retention-in-hours 1 \
    --region $REGION

if [ $? -eq 0 ]; then
    echo "✅ Kinesis Video Stream created successfully"
else
    echo "⚠️  Stream might already exist, continuing..."
fi

echo ""

# 2. Get streaming endpoint
echo "2. Getting streaming endpoint..."
ENDPOINT_RESPONSE=$(aws kinesisvideo get-data-endpoint \
    --stream-name "$STREAM_NAME" \
    --api-name PUT_MEDIA \
    --region $REGION \
    --output json)

if [ $? -eq 0 ]; then
    ENDPOINT=$(echo $ENDPOINT_RESPONSE | jq -r '.DataEndpoint')
    echo "✅ Streaming endpoint: $ENDPOINT"
else
    echo "❌ Failed to get streaming endpoint"
    exit 1
fi

echo ""
echo "🎯 Kinesis Video Streams Setup Complete!"
echo "========================================"
echo "Stream Name: $STREAM_NAME"
echo "Endpoint: $ENDPOINT"
echo ""
echo "🧪 Test with GStreamer (simpler than FFmpeg for Kinesis):"
echo "========================================================"
echo "# Install GStreamer first:"
echo "sudo apt-get update && sudo apt-get install -y gstreamer1.0-tools gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly"
echo ""
echo "# Then stream test pattern:"
echo "gst-launch-1.0 videotestsrc pattern=0 ! video/x-raw,width=320,height=240,framerate=25/1 ! \\"
echo "  videoconvert ! x264enc bitrate=2500 ! h264parse ! \\"
echo "  kvssink stream-name=\"$STREAM_NAME\" aws-region=\"$REGION\""
echo ""
echo "Or try FFmpeg with Kinesis (more complex):"
echo "ffmpeg -f lavfi -i \"color=green:size=320x240:rate=25\" \\"
echo "       -c:v libx264 -preset ultrafast -b:v 2500k \\"
echo "       -f kinesisvideo \"$STREAM_NAME\""
