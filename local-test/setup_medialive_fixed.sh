#!/bin/bash

# AWS MediaLive Infrastructure Setup - Fixed Version
echo "🎥 Setting up AWS MediaLive Infrastructure (Fixed)"
echo "=================================================="

REGION="us-east-1"
CHANNEL_NAME="spectrum-emulator-live"
INPUT_NAME="spectrum-rtmp-input"

echo "Region: $REGION"
echo "Channel: $CHANNEL_NAME"
echo "Input: $INPUT_NAME"
echo ""

# 1. Create Input Security Group first
echo "1. Creating Input Security Group..."
SECURITY_GROUP_RESPONSE=$(aws medialive create-input-security-group \
    --whitelist-rules '[{"Cidr": "0.0.0.0/0"}]' \
    --region $REGION \
    --output json)

if [ $? -eq 0 ]; then
    SECURITY_GROUP_ID=$(echo $SECURITY_GROUP_RESPONSE | jq -r '.SecurityGroup.Id')
    echo "✅ Security Group created: $SECURITY_GROUP_ID"
else
    echo "❌ Failed to create security group"
    exit 1
fi

echo ""

# 2. Create MediaLive Input (RTMP Push) - Fixed syntax
echo "2. Creating MediaLive RTMP Input..."
INPUT_RESPONSE=$(aws medialive create-input \
    --name "$INPUT_NAME" \
    --type RTMP_PUSH \
    --input-security-groups "$SECURITY_GROUP_ID" \
    --destinations '[{"StreamName": "spectrum-stream"}]' \
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
    echo "Response: $INPUT_RESPONSE"
    exit 1
fi

echo ""

# 3. Create S3 bucket for output
echo "3. Creating S3 bucket for MediaLive output..."
BUCKET_NAME="spectrum-medialive-output-$(date +%s)"
aws s3 mb s3://$BUCKET_NAME --region $REGION

if [ $? -eq 0 ]; then
    echo "✅ S3 bucket created: $BUCKET_NAME"
    
    # Make bucket public for HLS access
    aws s3api put-bucket-policy --bucket $BUCKET_NAME --policy '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "PublicReadGetObject",
                "Effect": "Allow",
                "Principal": "*",
                "Action": "s3:GetObject",
                "Resource": "arn:aws:s3:::'$BUCKET_NAME'/*"
            }
        ]
    }'
    echo "✅ S3 bucket made public for HLS access"
else
    echo "❌ Failed to create S3 bucket"
    exit 1
fi

echo ""
echo "🎯 MediaLive Input Setup Complete!"
echo "=================================="
echo "Input ID: $INPUT_ID"
echo "Security Group ID: $SECURITY_GROUP_ID"
echo "RTMP Endpoint: $INPUT_ENDPOINT"
echo "S3 Output Bucket: $BUCKET_NAME"
echo ""
echo "🧪 Test FFmpeg streaming to MediaLive:"
echo "======================================"
echo "ffmpeg -f lavfi -i \"color=red:size=320x240:rate=25\" \\"
echo "       -c:v libx264 -preset ultrafast \\"
echo "       -b:v 2500k -pix_fmt yuv420p \\"
echo "       -f flv \"$INPUT_ENDPOINT/spectrum-stream\" \\"
echo "       -t 30 -y"
echo ""
echo "Save these values:"
echo "export MEDIALIVE_INPUT_ID=$INPUT_ID"
echo "export MEDIALIVE_RTMP_ENDPOINT='$INPUT_ENDPOINT'"
echo "export MEDIALIVE_S3_BUCKET=$BUCKET_NAME"
