# ZX Spectrum Emulator - Complete Build Instructions

This document provides step-by-step instructions to recreate the entire ZX Spectrum Emulator infrastructure from scratch on a fresh AWS environment.

## 🎯 **Overview**

The ZX Spectrum Emulator is a complete web-based emulator with:
- Interactive ZX Spectrum emulation via FUSE
- Real-time HLS video streaming
- WebSocket-based control interface
- YouTube Live streaming integration
- AWS CloudFront global distribution
- ECS Fargate container orchestration

## 📋 **Prerequisites**

### AWS Account Setup
- AWS Account with administrative access
- AWS CLI installed and configured
- Docker installed on build machine
- Git repository access

### Required AWS Services
- ECS (Elastic Container Service)
- ECR (Elastic Container Registry)
- ALB (Application Load Balancer)
- CloudFront
- S3
- VPC with public subnets
- IAM roles and policies

## 🚀 **Quick Start**

```bash
# Clone the repository
git clone <your-repo-url>
cd SpeccyEmulator

# Run the complete setup script
./scripts/complete-setup.sh

# Or follow the detailed manual steps below
```

## 📖 **Table of Contents**

1. [Environment Setup](#environment-setup)
2. [AWS Infrastructure](#aws-infrastructure)
3. [Docker Image Build](#docker-image-build)
4. [ECS Configuration](#ecs-configuration)
5. [Load Balancer Setup](#load-balancer-setup)
6. [CloudFront Distribution](#cloudfront-distribution)
7. [DNS and SSL](#dns-and-ssl)
8. [Deployment](#deployment)
9. [Testing and Validation](#testing-and-validation)
10. [Troubleshooting](#troubleshooting)

---

## 1. Environment Setup

### 1.1 Fresh EC2 Instance Setup

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y \
    docker.io \
    docker-compose \
    awscli \
    git \
    curl \
    jq \
    unzip

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Verify installations
docker --version
aws --version
git --version
```

### 1.2 AWS CLI Configuration

```bash
# Configure AWS CLI with your credentials
aws configure

# Verify access
aws sts get-caller-identity
```

### 1.3 Environment Variables

Create a `.env` file with your specific values:

```bash
# Copy the template
cp .env.template .env

# Edit with your values
nano .env
```

Required environment variables:
```bash
AWS_ACCOUNT_ID=043309319786
AWS_REGION=us-east-1
PROJECT_NAME=spectrum-emulator
ENVIRONMENT=dev
YOUTUBE_STREAM_KEY=your-youtube-stream-key
DOMAIN_NAME=your-domain.com  # Optional
```

---

## 2. AWS Infrastructure

### 2.1 VPC and Networking

```bash
# Create VPC
aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=spectrum-emulator-vpc}]'

# Get VPC ID
VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=spectrum-emulator-vpc" \
    --query 'Vpcs[0].VpcId' --output text)

# Create Internet Gateway
aws ec2 create-internet-gateway \
    --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=spectrum-emulator-igw}]'

# Get IGW ID and attach to VPC
IGW_ID=$(aws ec2 describe-internet-gateways \
    --filters "Name=tag:Name,Values=spectrum-emulator-igw" \
    --query 'InternetGateways[0].InternetGatewayId' --output text)

aws ec2 attach-internet-gateway \
    --internet-gateway-id $IGW_ID \
    --vpc-id $VPC_ID

# Create public subnets in different AZs
aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.1.0/24 \
    --availability-zone us-east-1a \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=spectrum-emulator-subnet-1a}]'

aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.2.0/24 \
    --availability-zone us-east-1b \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=spectrum-emulator-subnet-1b}]'

# Get subnet IDs
SUBNET_1A=$(aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=spectrum-emulator-subnet-1a" \
    --query 'Subnets[0].SubnetId' --output text)

SUBNET_1B=$(aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=spectrum-emulator-subnet-1b" \
    --query 'Subnets[0].SubnetId' --output text)

# Enable auto-assign public IP
aws ec2 modify-subnet-attribute \
    --subnet-id $SUBNET_1A \
    --map-public-ip-on-launch

aws ec2 modify-subnet-attribute \
    --subnet-id $SUBNET_1B \
    --map-public-ip-on-launch

# Create route table and routes
aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=spectrum-emulator-rt}]'

RT_ID=$(aws ec2 describe-route-tables \
    --filters "Name=tag:Name,Values=spectrum-emulator-rt" \
    --query 'RouteTables[0].RouteTableId' --output text)

aws ec2 create-route \
    --route-table-id $RT_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $IGW_ID

# Associate subnets with route table
aws ec2 associate-route-table \
    --subnet-id $SUBNET_1A \
    --route-table-id $RT_ID

aws ec2 associate-route-table \
    --subnet-id $SUBNET_1B \
    --route-table-id $RT_ID
```

### 2.2 Security Groups

```bash
# Create security group for ALB
aws ec2 create-security-group \
    --group-name spectrum-emulator-alb-sg \
    --description "Security group for Spectrum Emulator ALB" \
    --vpc-id $VPC_ID

ALB_SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=spectrum-emulator-alb-sg" \
    --query 'SecurityGroups[0].GroupId' --output text)

# ALB security group rules
aws ec2 authorize-security-group-ingress \
    --group-id $ALB_SG_ID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
    --group-id $ALB_SG_ID \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0

# Create security group for ECS tasks
aws ec2 create-security-group \
    --group-name spectrum-emulator-ecs-sg \
    --description "Security group for Spectrum Emulator ECS tasks" \
    --vpc-id $VPC_ID

ECS_SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=spectrum-emulator-ecs-sg" \
    --query 'SecurityGroups[0].GroupId' --output text)

# ECS security group rules
aws ec2 authorize-security-group-ingress \
    --group-id $ECS_SG_ID \
    --protocol tcp \
    --port 8080 \
    --source-group $ALB_SG_ID

aws ec2 authorize-security-group-ingress \
    --group-id $ECS_SG_ID \
    --protocol tcp \
    --port 8765 \
    --source-group $ALB_SG_ID
```

### 2.3 S3 Buckets

```bash
# Create S3 bucket for web content
aws s3 mb s3://spectrum-emulator-web-${ENVIRONMENT}-${AWS_ACCOUNT_ID} --region $AWS_REGION

# Create S3 bucket for video streaming
aws s3 mb s3://spectrum-emulator-stream-${ENVIRONMENT}-${AWS_ACCOUNT_ID} --region $AWS_REGION

# Configure bucket policies for public read access
aws s3api put-bucket-policy \
    --bucket spectrum-emulator-web-${ENVIRONMENT}-${AWS_ACCOUNT_ID} \
    --policy file://aws/s3-web-bucket-policy.json

aws s3api put-bucket-policy \
    --bucket spectrum-emulator-stream-${ENVIRONMENT}-${AWS_ACCOUNT_ID} \
    --policy file://aws/s3-stream-bucket-policy.json

# Enable CORS for streaming bucket
aws s3api put-bucket-cors \
    --bucket spectrum-emulator-stream-${ENVIRONMENT}-${AWS_ACCOUNT_ID} \
    --cors-configuration file://aws/s3-cors-config.json
```

---

## 3. Docker Image Build

### 3.1 ECR Repository Setup

```bash
# Create ECR repository
aws ecr create-repository \
    --repository-name spectrum-emulator \
    --region $AWS_REGION

# Get login token and login to ECR
aws ecr get-login-password --region $AWS_REGION | \
    docker login --username AWS --password-stdin \
    ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
```

### 3.2 Build Complete Fix Image

```bash
# Build the complete emulator image
docker build -f complete-emulator.dockerfile -t spectrum-emulator:complete-fix .

# Tag for ECR
docker tag spectrum-emulator:complete-fix \
    ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/spectrum-emulator:complete-fix

# Push to ECR
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/spectrum-emulator:complete-fix

# Verify image in ECR
aws ecr describe-images \
    --repository-name spectrum-emulator \
    --region $AWS_REGION
```

---

## 4. ECS Configuration

### 4.1 IAM Roles

```bash
# Create ECS task execution role
aws iam create-role \
    --role-name ecsTaskExecutionRole \
    --assume-role-policy-document file://aws/ecs-task-execution-role-trust-policy.json

# Attach managed policy
aws iam attach-role-policy \
    --role-name ecsTaskExecutionRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

# Create custom policy for S3 access
aws iam create-policy \
    --policy-name SpectrumEmulatorS3Policy \
    --policy-document file://aws/s3-access-policy.json

# Attach S3 policy to execution role
aws iam attach-role-policy \
    --role-name ecsTaskExecutionRole \
    --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/SpectrumEmulatorS3Policy
```

### 4.2 ECS Cluster

```bash
# Create ECS cluster
aws ecs create-cluster \
    --cluster-name spectrum-emulator-cluster-${ENVIRONMENT} \
    --capacity-providers FARGATE \
    --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1

# Create CloudWatch log group
aws logs create-log-group \
    --log-group-name /ecs/spectrum-emulator-streaming \
    --region $AWS_REGION
```

### 4.3 Task Definition

```bash
# Update task definition with your account ID and region
sed -i "s/043309319786/${AWS_ACCOUNT_ID}/g" aws/task-definition-complete-fix.json
sed -i "s/us-east-1/${AWS_REGION}/g" aws/task-definition-complete-fix.json

# Register task definition
aws ecs register-task-definition \
    --cli-input-json file://aws/task-definition-complete-fix.json
```

---

## 5. Load Balancer Setup

### 5.1 Application Load Balancer

```bash
# Create Application Load Balancer
aws elbv2 create-load-balancer \
    --name spectrum-emulator-alb-${ENVIRONMENT} \
    --subnets $SUBNET_1A $SUBNET_1B \
    --security-groups $ALB_SG_ID \
    --scheme internet-facing \
    --type application \
    --ip-address-type ipv4

# Get ALB ARN
ALB_ARN=$(aws elbv2 describe-load-balancers \
    --names spectrum-emulator-alb-${ENVIRONMENT} \
    --query 'LoadBalancers[0].LoadBalancerArn' --output text)

# Get ALB DNS name for later use
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --names spectrum-emulator-alb-${ENVIRONMENT} \
    --query 'LoadBalancers[0].DNSName' --output text)

echo "ALB DNS: $ALB_DNS"
```

### 5.2 Target Groups

```bash
# Create target group for API (health checks)
aws elbv2 create-target-group \
    --name spectrum-api-tg-${ENVIRONMENT} \
    --protocol HTTP \
    --port 8080 \
    --vpc-id $VPC_ID \
    --target-type ip \
    --health-check-path /health \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 10 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 3

# Create target group for WebSocket
aws elbv2 create-target-group \
    --name spectrum-ws-tg-${ENVIRONMENT} \
    --protocol HTTP \
    --port 8765 \
    --vpc-id $VPC_ID \
    --target-type ip \
    --health-check-path /health \
    --health-check-port 8080 \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 10 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 3

# Get target group ARNs
API_TG_ARN=$(aws elbv2 describe-target-groups \
    --names spectrum-api-tg-${ENVIRONMENT} \
    --query 'TargetGroups[0].TargetGroupArn' --output text)

WS_TG_ARN=$(aws elbv2 describe-target-groups \
    --names spectrum-ws-tg-${ENVIRONMENT} \
    --query 'TargetGroups[0].TargetGroupArn' --output text)
```

### 5.3 Load Balancer Listeners

```bash
# Create HTTP listener (will redirect to HTTPS in production)
aws elbv2 create-listener \
    --load-balancer-arn $ALB_ARN \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=$API_TG_ARN

# Get listener ARN
LISTENER_ARN=$(aws elbv2 describe-listeners \
    --load-balancer-arn $ALB_ARN \
    --query 'Listeners[0].ListenerArn' --output text)

# Create listener rules for WebSocket routing
aws elbv2 create-rule \
    --listener-arn $LISTENER_ARN \
    --priority 100 \
    --conditions Field=path-pattern,Values="/ws/*" \
    --actions Type=forward,TargetGroupArn=$WS_TG_ARN
```

---

## 6. CloudFront Distribution

### 6.1 Create Distribution

```bash
# Create CloudFront distribution configuration
cat > cloudfront-config.json << EOF
{
    "CallerReference": "spectrum-emulator-$(date +%s)",
    "Comment": "ZX Spectrum Emulator Distribution",
    "DefaultCacheBehavior": {
        "TargetOriginId": "S3-spectrum-emulator-web",
        "ViewerProtocolPolicy": "redirect-to-https",
        "TrustedSigners": {
            "Enabled": false,
            "Quantity": 0
        },
        "ForwardedValues": {
            "QueryString": false,
            "Cookies": {
                "Forward": "none"
            }
        },
        "MinTTL": 0,
        "DefaultTTL": 86400,
        "MaxTTL": 31536000
    },
    "Origins": {
        "Quantity": 3,
        "Items": [
            {
                "Id": "S3-spectrum-emulator-web",
                "DomainName": "spectrum-emulator-web-${ENVIRONMENT}-${AWS_ACCOUNT_ID}.s3.amazonaws.com",
                "S3OriginConfig": {
                    "OriginAccessIdentity": ""
                }
            },
            {
                "Id": "S3-spectrum-emulator-stream",
                "DomainName": "spectrum-emulator-stream-${ENVIRONMENT}-${AWS_ACCOUNT_ID}.s3.amazonaws.com",
                "S3OriginConfig": {
                    "OriginAccessIdentity": ""
                }
            },
            {
                "Id": "ALB-spectrum-emulator",
                "DomainName": "${ALB_DNS}",
                "CustomOriginConfig": {
                    "HTTPPort": 80,
                    "HTTPSPort": 443,
                    "OriginProtocolPolicy": "http-only"
                }
            }
        ]
    },
    "CacheBehaviors": {
        "Quantity": 2,
        "Items": [
            {
                "PathPattern": "/hls/*",
                "TargetOriginId": "S3-spectrum-emulator-stream",
                "ViewerProtocolPolicy": "https-only",
                "TrustedSigners": {
                    "Enabled": false,
                    "Quantity": 0
                },
                "ForwardedValues": {
                    "QueryString": false,
                    "Cookies": {
                        "Forward": "none"
                    }
                },
                "MinTTL": 0,
                "DefaultTTL": 5,
                "MaxTTL": 10
            },
            {
                "PathPattern": "/ws/*",
                "TargetOriginId": "ALB-spectrum-emulator",
                "ViewerProtocolPolicy": "https-only",
                "TrustedSigners": {
                    "Enabled": false,
                    "Quantity": 0
                },
                "ForwardedValues": {
                    "QueryString": true,
                    "Cookies": {
                        "Forward": "all"
                    },
                    "Headers": {
                        "Quantity": 4,
                        "Items": [
                            "Sec-WebSocket-Key",
                            "Sec-WebSocket-Version",
                            "Sec-WebSocket-Protocol",
                            "Sec-WebSocket-Extensions"
                        ]
                    }
                },
                "MinTTL": 0,
                "DefaultTTL": 0,
                "MaxTTL": 0
            }
        ]
    },
    "Enabled": true,
    "PriceClass": "PriceClass_100"
}
EOF

# Create CloudFront distribution
aws cloudfront create-distribution \
    --distribution-config file://cloudfront-config.json

# Get distribution ID and domain name
DISTRIBUTION_ID=$(aws cloudfront list-distributions \
    --query 'DistributionList.Items[?Comment==`ZX Spectrum Emulator Distribution`].Id' \
    --output text)

CLOUDFRONT_DOMAIN=$(aws cloudfront get-distribution \
    --id $DISTRIBUTION_ID \
    --query 'Distribution.DomainName' --output text)

echo "CloudFront Domain: $CLOUDFRONT_DOMAIN"
```

---

## 7. ECS Service Deployment

### 7.1 Create ECS Service

```bash
# Create ECS service
aws ecs create-service \
    --cluster spectrum-emulator-cluster-${ENVIRONMENT} \
    --service-name spectrum-youtube-streaming \
    --task-definition spectrum-emulator-streaming:1 \
    --desired-count 1 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_1A,$SUBNET_1B],securityGroups=[$ECS_SG_ID],assignPublicIp=ENABLED}" \
    --load-balancers targetGroupArn=$API_TG_ARN,containerName=spectrum-emulator-streamer,containerPort=8080 targetGroupArn=$WS_TG_ARN,containerName=spectrum-emulator-streamer,containerPort=8765 \
    --health-check-grace-period-seconds 1800

# Wait for service to stabilize
aws ecs wait services-stable \
    --cluster spectrum-emulator-cluster-${ENVIRONMENT} \
    --services spectrum-youtube-streaming
```

---

## 8. Web Content Deployment

### 8.1 Upload Web Files

```bash
# Upload web content to S3
aws s3 sync web/ s3://spectrum-emulator-web-${ENVIRONMENT}-${AWS_ACCOUNT_ID}/ \
    --delete \
    --cache-control "max-age=86400"

# Upload specific files with different cache settings
aws s3 cp web/index.html s3://spectrum-emulator-web-${ENVIRONMENT}-${AWS_ACCOUNT_ID}/ \
    --cache-control "max-age=300"

# Set content types
aws s3 cp web/js/ s3://spectrum-emulator-web-${ENVIRONMENT}-${AWS_ACCOUNT_ID}/js/ \
    --recursive \
    --content-type "application/javascript"

aws s3 cp web/css/ s3://spectrum-emulator-web-${ENVIRONMENT}-${AWS_ACCOUNT_ID}/css/ \
    --recursive \
    --content-type "text/css"
```

### 8.2 Update Configuration

```bash
# Update JavaScript configuration with CloudFront domain
sed -i "s/d112s3ps8xh739.cloudfront.net/${CLOUDFRONT_DOMAIN}/g" web/js/config.js

# Re-upload updated config
aws s3 cp web/js/config.js s3://spectrum-emulator-web-${ENVIRONMENT}-${AWS_ACCOUNT_ID}/js/ \
    --content-type "application/javascript"
```

---

## 9. Testing and Validation

### 9.1 Health Checks

```bash
# Check ECS service status
aws ecs describe-services \
    --cluster spectrum-emulator-cluster-${ENVIRONMENT} \
    --services spectrum-youtube-streaming

# Check target group health
aws elbv2 describe-target-health \
    --target-group-arn $API_TG_ARN

aws elbv2 describe-target-health \
    --target-group-arn $WS_TG_ARN

# Test health endpoint directly
curl -f http://$ALB_DNS/health
```

### 9.2 Functional Tests

```bash
# Test web interface
curl -I https://$CLOUDFRONT_DOMAIN

# Test HLS stream endpoint
curl -I https://$CLOUDFRONT_DOMAIN/hls/stream.m3u8

# Test WebSocket upgrade (should return 400 without proper headers)
curl -v --no-buffer \
    --header "Connection: Upgrade" \
    --header "Upgrade: websocket" \
    --header "Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==" \
    --header "Sec-WebSocket-Version: 13" \
    https://$CLOUDFRONT_DOMAIN/ws/
```

### 9.3 Container Logs

```bash
# View container logs
aws logs tail "/ecs/spectrum-emulator-streaming" --follow --region $AWS_REGION

# Check for specific log patterns
aws logs filter-log-events \
    --log-group-name "/ecs/spectrum-emulator-streaming" \
    --filter-pattern "ERROR" \
    --region $AWS_REGION
```

---

## 10. Troubleshooting

### 10.1 Common Issues

**Container Health Check Failures**
```bash
# Check container logs for startup errors
aws logs tail "/ecs/spectrum-emulator-streaming" --follow

# Verify health endpoint responds
curl -f http://$ALB_DNS/health

# Check ECS service events
aws ecs describe-services \
    --cluster spectrum-emulator-cluster-${ENVIRONMENT} \
    --services spectrum-youtube-streaming \
    --query 'services[0].events'
```

**WebSocket Connection Issues**
```bash
# Verify ALB listener rules
aws elbv2 describe-rules --listener-arn $LISTENER_ARN

# Check target group health
aws elbv2 describe-target-health --target-group-arn $WS_TG_ARN

# Test WebSocket endpoint
curl -v --no-buffer \
    --header "Connection: Upgrade" \
    --header "Upgrade: websocket" \
    https://$CLOUDFRONT_DOMAIN/ws/
```

**Video Stream Not Working**
```bash
# Check S3 bucket contents
aws s3 ls s3://spectrum-emulator-stream-${ENVIRONMENT}-${AWS_ACCOUNT_ID}/hls/

# Verify HLS manifest
curl -s https://$CLOUDFRONT_DOMAIN/hls/stream.m3u8

# Check FFmpeg process in container
aws logs filter-log-events \
    --log-group-name "/ecs/spectrum-emulator-streaming" \
    --filter-pattern "ffmpeg"
```

### 10.2 Cleanup Commands

```bash
# Delete ECS service
aws ecs update-service \
    --cluster spectrum-emulator-cluster-${ENVIRONMENT} \
    --service spectrum-youtube-streaming \
    --desired-count 0

aws ecs delete-service \
    --cluster spectrum-emulator-cluster-${ENVIRONMENT} \
    --service spectrum-youtube-streaming

# Delete CloudFront distribution
aws cloudfront delete-distribution \
    --id $DISTRIBUTION_ID \
    --if-match $(aws cloudfront get-distribution --id $DISTRIBUTION_ID --query 'ETag' --output text)

# Delete ALB and target groups
aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN
aws elbv2 delete-target-group --target-group-arn $API_TG_ARN
aws elbv2 delete-target-group --target-group-arn $WS_TG_ARN

# Delete S3 buckets
aws s3 rb s3://spectrum-emulator-web-${ENVIRONMENT}-${AWS_ACCOUNT_ID} --force
aws s3 rb s3://spectrum-emulator-stream-${ENVIRONMENT}-${AWS_ACCOUNT_ID} --force

# Delete VPC resources
aws ec2 delete-vpc --vpc-id $VPC_ID
```

---

## 11. Production Considerations

### 11.1 SSL/TLS Certificate

```bash
# Request SSL certificate via ACM
aws acm request-certificate \
    --domain-name $DOMAIN_NAME \
    --validation-method DNS \
    --region us-east-1  # CloudFront requires certificates in us-east-1

# Update CloudFront distribution to use SSL certificate
# Update ALB listener to use HTTPS
```

### 11.2 Monitoring and Alerting

```bash
# Create CloudWatch alarms
aws cloudwatch put-metric-alarm \
    --alarm-name "SpectrumEmulator-HighCPU" \
    --alarm-description "High CPU utilization" \
    --metric-name CPUUtilization \
    --namespace AWS/ECS \
    --statistic Average \
    --period 300 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2

# Set up log retention
aws logs put-retention-policy \
    --log-group-name "/ecs/spectrum-emulator-streaming" \
    --retention-in-days 30
```

### 11.3 Backup and Recovery

```bash
# Create ECR image backup
docker pull ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/spectrum-emulator:complete-fix
docker save spectrum-emulator:complete-fix > spectrum-emulator-backup.tar

# Export task definition
aws ecs describe-task-definition \
    --task-definition spectrum-emulator-streaming \
    --query 'taskDefinition' > task-definition-backup.json
```

---

## 🎉 **Completion**

After following these instructions, you should have a fully functional ZX Spectrum Emulator with:

- ✅ Interactive web interface
- ✅ Real-time video streaming
- ✅ WebSocket-based controls
- ✅ YouTube live streaming capability
- ✅ Global CloudFront distribution
- ✅ Scalable ECS Fargate deployment

**Access your emulator at**: `https://$CLOUDFRONT_DOMAIN`

For support or issues, refer to the troubleshooting section or check the container logs.
