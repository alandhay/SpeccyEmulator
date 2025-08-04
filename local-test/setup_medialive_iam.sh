#!/bin/bash

# Create IAM Role for MediaLive
echo "🔐 Setting up MediaLive IAM Role"
echo "==============================="

ROLE_NAME="MediaLiveAccessRole"

# 1. Create trust policy
cat > /tmp/medialive-trust-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "medialive.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

# 2. Create the role
echo "Creating IAM role: $ROLE_NAME"
aws iam create-role \
    --role-name $ROLE_NAME \
    --assume-role-policy-document file:///tmp/medialive-trust-policy.json \
    --description "Role for MediaLive to access S3 and other services"

# 3. Attach managed policies
echo "Attaching MediaLive service policy..."
aws iam attach-role-policy \
    --role-name $ROLE_NAME \
    --policy-arn arn:aws:iam::aws:policy/AWSElementalMediaLiveFullAccess

# 4. Create custom S3 policy
cat > /tmp/medialive-s3-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::spectrum-medialive-output-*",
                "arn:aws:s3:::spectrum-medialive-output-*/*"
            ]
        }
    ]
}
EOF

# 5. Create and attach S3 policy
echo "Creating S3 access policy..."
aws iam create-policy \
    --policy-name MediaLiveS3Access \
    --policy-document file:///tmp/medialive-s3-policy.json \
    --description "S3 access for MediaLive output"

aws iam attach-role-policy \
    --role-name $ROLE_NAME \
    --policy-arn arn:aws:iam::043309319786:policy/MediaLiveS3Access

echo ""
echo "✅ IAM Role setup complete!"
echo "Role ARN: arn:aws:iam::043309319786:role/$ROLE_NAME"
echo ""
echo "Now run: ./setup_medialive.sh"
