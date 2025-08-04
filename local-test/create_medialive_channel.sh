#!/bin/bash

# Create MediaLive Channel for RTMP Input
echo "📺 Creating MediaLive Channel"
echo "============================"

INPUT_ID="3241154"
BUCKET_NAME="spectrum-medialive-output-1754250326"
CHANNEL_NAME="spectrum-live-channel"

echo "Input ID: $INPUT_ID"
echo "S3 Bucket: $BUCKET_NAME"
echo "Channel Name: $CHANNEL_NAME"
echo ""

# Create channel configuration
cat > /tmp/medialive-channel.json << EOF
{
    "Name": "$CHANNEL_NAME",
    "RoleArn": "arn:aws:iam::043309319786:role/MediaLiveAccessRole",
    "InputSpecification": {
        "Codec": "AVC",
        "Resolution": "SD",
        "MaximumBitrate": "MAX_10_MBPS"
    },
    "InputAttachments": [
        {
            "InputId": "$INPUT_ID",
            "InputAttachmentName": "spectrum-input",
            "InputSettings": {
                "SourceEndBehavior": "CONTINUE"
            }
        }
    ],
    "Destinations": [
        {
            "Id": "hls-destination",
            "Settings": [
                {
                    "Url": "s3://$BUCKET_NAME/live/"
                }
            ]
        }
    ],
    "EncoderSettings": {
        "AudioDescriptions": [],
        "VideoDescriptions": [
            {
                "Name": "video_480p",
                "CodecSettings": {
                    "H264Settings": {
                        "Bitrate": 2500000,
                        "FramerateControl": "SPECIFIED",
                        "FramerateNumerator": 25,
                        "FramerateDenominator": 1,
                        "GopSize": 50,
                        "GopSizeUnits": "FRAMES",
                        "Profile": "BASELINE",
                        "RateControlMode": "CBR"
                    }
                },
                "Height": 240,
                "Width": 320
            }
        ],
        "OutputGroups": [
            {
                "Name": "HLS_Output",
                "OutputGroupSettings": {
                    "HlsGroupSettings": {
                        "Destination": {
                            "DestinationRefId": "hls-destination"
                        },
                        "SegmentLength": 2,
                        "ManifestName": "spectrum",
                        "HlsCdnSettings": {
                            "HlsBasicPutSettings": {
                                "ConnectionRetryInterval": 1,
                                "FilecacheDuration": 300,
                                "NumRetries": 10
                            }
                        }
                    }
                },
                "Outputs": [
                    {
                        "OutputName": "spectrum_320x240",
                        "VideoDescriptionName": "video_480p",
                        "OutputSettings": {
                            "HlsOutputSettings": {
                                "NameModifier": "_320x240"
                            }
                        }
                    }
                ]
            }
        ]
    }
}
EOF

echo "Creating MediaLive channel..."
CHANNEL_RESPONSE=$(aws medialive create-channel \
    --cli-input-json file:///tmp/medialive-channel.json \
    --region us-east-1 \
    --output json)

if [ $? -eq 0 ]; then
    CHANNEL_ID=$(echo $CHANNEL_RESPONSE | jq -r '.Channel.Id')
    echo "✅ Channel created successfully!"
    echo "   Channel ID: $CHANNEL_ID"
    
    echo ""
    echo "Starting the channel..."
    aws medialive start-channel --channel-id $CHANNEL_ID --region us-east-1
    
    if [ $? -eq 0 ]; then
        echo "✅ Channel starting..."
        echo ""
        echo "🎯 MediaLive Setup Complete!"
        echo "============================"
        echo "Channel ID: $CHANNEL_ID"
        echo "RTMP Endpoint: rtmp://52.1.244.212:1935/spectrum-stream/spectrum-stream"
        echo "HLS Output: https://s3.amazonaws.com/$BUCKET_NAME/live/spectrum_320x240.m3u8"
        echo ""
        echo "Wait 2-3 minutes for channel to start, then test streaming!"
    else
        echo "❌ Failed to start channel"
    fi
else
    echo "❌ Failed to create channel"
    echo "Response: $CHANNEL_RESPONSE"
fi
