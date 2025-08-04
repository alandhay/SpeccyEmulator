#!/bin/bash

# Create Simple MediaLive Channel
echo "📺 Creating Simple MediaLive Channel"
echo "===================================="

INPUT_ID="3241154"
BUCKET_NAME="spectrum-medialive-output-1754250326"

# Simplified channel configuration
cat > /tmp/simple-channel.json << EOF
{
    "Name": "spectrum-simple-channel",
    "RoleArn": "arn:aws:iam::043309319786:role/MediaLiveAccessRole",
    "InputSpecification": {
        "Codec": "AVC",
        "Resolution": "SD",
        "MaximumBitrate": "MAX_10_MBPS"
    },
    "InputAttachments": [
        {
            "InputId": "$INPUT_ID",
            "InputAttachmentName": "spectrum-input"
        }
    ],
    "Destinations": [
        {
            "Id": "hls-dest",
            "Settings": [
                {
                    "Url": "s3://$BUCKET_NAME/live/"
                }
            ]
        }
    ],
    "EncoderSettings": {
        "TimecodeConfig": {
            "Source": "EMBEDDED"
        },
        "AudioDescriptions": [],
        "VideoDescriptions": [
            {
                "Name": "video_320x240",
                "CodecSettings": {
                    "H264Settings": {
                        "Bitrate": 2500000,
                        "FramerateControl": "SPECIFIED",
                        "FramerateNumerator": 25,
                        "FramerateDenominator": 1
                    }
                },
                "Height": 240,
                "Width": 320
            }
        ],
        "OutputGroups": [
            {
                "Name": "HLS_Group",
                "OutputGroupSettings": {
                    "HlsGroupSettings": {
                        "Destination": {
                            "DestinationRefId": "hls-dest"
                        },
                        "SegmentLength": 2,
                        "HlsCdnSettings": {
                            "HlsBasicPutSettings": {}
                        }
                    }
                },
                "Outputs": [
                    {
                        "OutputName": "hls_output",
                        "VideoDescriptionName": "video_320x240",
                        "OutputSettings": {
                            "HlsOutputSettings": {
                                "HlsSettings": {
                                    "StandardHlsSettings": {
                                        "M3u8Settings": {}
                                    }
                                }
                            }
                        }
                    }
                ]
            }
        ]
    }
}
EOF

echo "Creating simplified MediaLive channel..."
CHANNEL_RESPONSE=$(aws medialive create-channel \
    --cli-input-json file:///tmp/simple-channel.json \
    --region us-east-1 \
    --output json)

if [ $? -eq 0 ]; then
    CHANNEL_ID=$(echo $CHANNEL_RESPONSE | jq -r '.Channel.Id')
    echo "✅ Channel created: $CHANNEL_ID"
    
    echo "Starting channel..."
    aws medialive start-channel --channel-id $CHANNEL_ID --region us-east-1
    
    echo ""
    echo "🎯 Channel Starting!"
    echo "==================="
    echo "Channel ID: $CHANNEL_ID"
    echo "RTMP Endpoint: rtmp://52.1.244.212:1935/spectrum-stream/spectrum-stream"
    echo ""
    echo "⏳ Wait 2-3 minutes for channel to start, then test streaming!"
    echo ""
    echo "Test command:"
    echo "ffmpeg -f lavfi -i \"color=blue:size=320x240:rate=25\" \\"
    echo "       -c:v libx264 -preset ultrafast \\"
    echo "       -b:v 2500k -pix_fmt yuv420p \\"
    echo "       -f flv \"rtmp://52.1.244.212:1935/spectrum-stream/spectrum-stream\" \\"
    echo "       -t 30 -y"
else
    echo "❌ Failed to create channel"
    echo "Error: $CHANNEL_RESPONSE"
fi
