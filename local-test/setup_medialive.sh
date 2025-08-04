#!/bin/bash

# AWS MediaLive Infrastructure Setup for ZX Spectrum Emulator
echo "🎥 Setting up AWS MediaLive Infrastructure"
echo "=========================================="

REGION="us-east-1"
CHANNEL_NAME="spectrum-emulator-live"
INPUT_NAME="spectrum-rtmp-input"

echo "Region: $REGION"
echo "Channel: $CHANNEL_NAME"
echo "Input: $INPUT_NAME"
echo ""

# 1. Create MediaLive Input (RTMP Push)
echo "1. Creating MediaLive RTMP Input..."
INPUT_RESPONSE=$(aws medialive create-input \
    --name "$INPUT_NAME" \
    --type RTMP_PUSH \
    --input-security-groups \
    --destinations '[{"streamName": "spectrum-stream"}]' \
    --region $REGION \
    --output json)

if [ $? -eq 0 ]; then
    INPUT_ID=$(echo $INPUT_RESPONSE | jq -r '.Input.Id')
    INPUT_ENDPOINT=$(echo $INPUT_RESPONSE | jq -r '.Input.Destinations[0].Url')
    echo "✅ Input created successfully"
    echo "   Input ID: $INPUT_ID"
    echo "   RTMP Endpoint: $INPUT_ENDPOINT"
else
    echo "❌ Failed to create input"
    exit 1
fi

echo ""

# 2. Create S3 bucket for output
echo "2. Creating S3 bucket for MediaLive output..."
BUCKET_NAME="spectrum-medialive-output-$(date +%s)"
aws s3 mb s3://$BUCKET_NAME --region $REGION

if [ $? -eq 0 ]; then
    echo "✅ S3 bucket created: $BUCKET_NAME"
else
    echo "❌ Failed to create S3 bucket"
    exit 1
fi

echo ""

# 3. Create MediaLive Channel
echo "3. Creating MediaLive Channel..."
CHANNEL_CONFIG=$(cat << EOF
{
    "Name": "$CHANNEL_NAME",
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
            "Id": "hls-output",
            "Settings": [
                {
                    "Url": "s3://$BUCKET_NAME/live/",
                    "Username": "",
                    "PasswordParam": ""
                }
            ]
        }
    ],
    "EncoderSettings": {
        "AudioDescriptions": [],
        "VideoDescriptions": [
            {
                "Name": "video_1",
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
                "Name": "HLS",
                "OutputGroupSettings": {
                    "HlsGroupSettings": {
                        "Destination": {
                            "DestinationRefId": "hls-output"
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
                        "OutputName": "spectrum-output",
                        "VideoDescriptionName": "video_1",
                        "OutputSettings": {
                            "HlsOutputSettings": {
                                "NameModifier": "_320x240"
                            }
                        }
                    }
                ]
            }
        ]
    },
    "RoleArn": "arn:aws:iam::043309319786:role/MediaLiveAccessRole"
}
EOF
)

echo "$CHANNEL_CONFIG" > /tmp/medialive-channel.json

CHANNEL_RESPONSE=$(aws medialive create-channel \
    --cli-input-json file:///tmp/medialive-channel.json \
    --region $REGION \
    --output json)

if [ $? -eq 0 ]; then
    CHANNEL_ID=$(echo $CHANNEL_RESPONSE | jq -r '.Channel.Id')
    echo "✅ Channel created successfully"
    echo "   Channel ID: $CHANNEL_ID"
else
    echo "❌ Failed to create channel"
    echo "Response: $CHANNEL_RESPONSE"
    exit 1
fi

echo ""
echo "🎯 MediaLive Setup Complete!"
echo "============================"
echo "Input ID: $INPUT_ID"
echo "Channel ID: $CHANNEL_ID"
echo "RTMP Endpoint: $INPUT_ENDPOINT"
echo "S3 Output Bucket: $BUCKET_NAME"
echo ""
echo "Next steps:"
echo "1. Start the MediaLive channel"
echo "2. Stream to the RTMP endpoint"
echo "3. Access HLS output from S3"
echo ""
echo "Save these values:"
echo "export MEDIALIVE_INPUT_ID=$INPUT_ID"
echo "export MEDIALIVE_CHANNEL_ID=$CHANNEL_ID"
echo "export MEDIALIVE_RTMP_ENDPOINT='$INPUT_ENDPOINT'"
echo "export MEDIALIVE_S3_BUCKET=$BUCKET_NAME"
