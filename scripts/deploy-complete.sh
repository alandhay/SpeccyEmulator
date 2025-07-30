#!/bin/bash

# Complete AWS Deployment Script for ZX Spectrum Emulator
# Deploys infrastructure, builds Docker image, and deploys ECS service

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}🚀 Complete AWS Deployment for ZX Spectrum Emulator${NC}"

# Configuration
INFRASTRUCTURE_STACK="spectrum-emulator-infrastructure"
ECS_STACK="spectrum-emulator-ecs"
ENVIRONMENT="dev"
REGION="us-east-1"
ECR_REPOSITORY="spectrum-emulator"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        --domain)
            DOMAIN_NAME="$2"
            shift 2
            ;;
        --certificate-arn)
            CERTIFICATE_ARN="$2"
            shift 2
            ;;
        --skip-infrastructure)
            SKIP_INFRASTRUCTURE=true
            shift
            ;;
        --skip-docker)
            SKIP_DOCKER=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --environment ENV         Environment name (dev, staging, prod) [default: dev]"
            echo "  --region REGION           AWS region [default: us-east-1]"
            echo "  --domain DOMAIN           Custom domain name (optional)"
            echo "  --certificate-arn ARN     ACM certificate ARN (optional)"
            echo "  --skip-infrastructure     Skip infrastructure deployment"
            echo "  --skip-docker             Skip Docker build and push"
            echo "  --help                    Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "Environment: $ENVIRONMENT"
echo "Region: $REGION"

# Check AWS CLI configuration
echo -e "${BLUE}Checking AWS configuration...${NC}"
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo -e "${RED}❌ AWS CLI not configured. Please run 'aws configure'${NC}"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✅ AWS Account: $ACCOUNT_ID${NC}"

# Step 1: Deploy Infrastructure
if [ "$SKIP_INFRASTRUCTURE" != "true" ]; then
    echo -e "${BLUE}Step 1: Deploying infrastructure...${NC}"
    
    # Build CloudFormation parameters
    INFRA_PARAMETERS="ParameterKey=Environment,ParameterValue=$ENVIRONMENT"
    
    if [ ! -z "$DOMAIN_NAME" ]; then
        INFRA_PARAMETERS="$INFRA_PARAMETERS ParameterKey=DomainName,ParameterValue=$DOMAIN_NAME"
    fi
    
    if [ ! -z "$CERTIFICATE_ARN" ]; then
        INFRA_PARAMETERS="$INFRA_PARAMETERS ParameterKey=CertificateArn,ParameterValue=$CERTIFICATE_ARN"
    fi
    
    aws cloudformation deploy \
        --template-file "$PROJECT_ROOT/infrastructure/cloudfront-stack.yaml" \
        --stack-name "$INFRASTRUCTURE_STACK" \
        --parameter-overrides $INFRA_PARAMETERS \
        --capabilities CAPABILITY_IAM \
        --region "$REGION" \
        --no-fail-on-empty-changeset
    
    echo -e "${GREEN}✅ Infrastructure deployed${NC}"
else
    echo -e "${YELLOW}⏭️  Skipping infrastructure deployment${NC}"
fi

# Get infrastructure outputs
echo -e "${BLUE}Getting infrastructure outputs...${NC}"
CLOUDFRONT_DOMAIN=$(aws cloudformation describe-stacks \
    --stack-name "$INFRASTRUCTURE_STACK" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDomainName`].OutputValue' \
    --output text)

WEB_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name "$INFRASTRUCTURE_STACK" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`WebContentBucketName`].OutputValue' \
    --output text)

STREAM_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name "$INFRASTRUCTURE_STACK" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`StreamBucketName`].OutputValue' \
    --output text)

echo -e "${GREEN}✅ Infrastructure outputs retrieved${NC}"

# Step 2: Create ECR Repository
echo -e "${BLUE}Step 2: Setting up ECR repository...${NC}"
if ! aws ecr describe-repositories --repository-names "$ECR_REPOSITORY" --region "$REGION" >/dev/null 2>&1; then
    echo "Creating ECR repository..."
    aws ecr create-repository \
        --repository-name "$ECR_REPOSITORY" \
        --region "$REGION" \
        --image-scanning-configuration scanOnPush=true \
        --encryption-configuration encryptionType=AES256
fi

ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPOSITORY"
echo -e "${GREEN}✅ ECR repository ready: $ECR_URI${NC}"

# Step 3: Build and Push Docker Image
if [ "$SKIP_DOCKER" != "true" ]; then
    echo -e "${BLUE}Step 3: Building and pushing Docker image...${NC}"
    
    # Login to ECR
    aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"
    
    # Build Docker image
    echo "Building Docker image..."
    cd "$PROJECT_ROOT"
    docker build -t "$ECR_REPOSITORY:latest" .
    docker tag "$ECR_REPOSITORY:latest" "$ECR_URI:latest"
    docker tag "$ECR_REPOSITORY:latest" "$ECR_URI:$ENVIRONMENT"
    
    # Push to ECR
    echo "Pushing Docker image to ECR..."
    docker push "$ECR_URI:latest"
    docker push "$ECR_URI:$ENVIRONMENT"
    
    echo -e "${GREEN}✅ Docker image built and pushed${NC}"
else
    echo -e "${YELLOW}⏭️  Skipping Docker build${NC}"
fi

# Step 4: Deploy ECS Service
echo -e "${BLUE}Step 4: Deploying ECS service...${NC}"

aws cloudformation deploy \
    --template-file "$PROJECT_ROOT/infrastructure/ecs-stack.yaml" \
    --stack-name "$ECS_STACK" \
    --parameter-overrides \
        "ParameterKey=Environment,ParameterValue=$ENVIRONMENT" \
        "ParameterKey=InfrastructureStackName,ParameterValue=$INFRASTRUCTURE_STACK" \
        "ParameterKey=ImageUri,ParameterValue=$ECR_URI:$ENVIRONMENT" \
    --capabilities CAPABILITY_IAM \
    --region "$REGION" \
    --no-fail-on-empty-changeset

echo -e "${GREEN}✅ ECS service deployed${NC}"

# Step 5: Update Web Configuration and Deploy
echo -e "${BLUE}Step 5: Updating and deploying web content...${NC}"

# Update web configuration
cat > "$PROJECT_ROOT/web/js/config.js" << EOF
// AWS Configuration - Auto-generated by deploy script
window.AWS_CONFIG = {
    cloudfront_domain: 'https://$CLOUDFRONT_DOMAIN',
    websocket_url: 'wss://$CLOUDFRONT_DOMAIN/ws',
    api_base_url: 'https://$CLOUDFRONT_DOMAIN/api',
    stream_base_url: 'https://$CLOUDFRONT_DOMAIN/stream',
    environment: '$ENVIRONMENT'
};
EOF

# Update HTML to include config
if ! grep -q "config.js" "$PROJECT_ROOT/web/index.html"; then
    sed -i 's|<script src="js/hls.min.js"></script>|<script src="js/config.js"></script>\n    <script src="js/hls.min.js"></script>|' "$PROJECT_ROOT/web/index.html"
fi

# Update info panel with correct URLs
sed -i "s|ws://localhost:8765|wss://$CLOUDFRONT_DOMAIN/ws|g" "$PROJECT_ROOT/web/index.html"
sed -i "s|http://localhost:8080/stream/hls/stream.m3u8|https://$CLOUDFRONT_DOMAIN/stream/hls/stream.m3u8|g" "$PROJECT_ROOT/web/index.html"

# Deploy web content to S3
aws s3 sync "$PROJECT_ROOT/web/" "s3://$WEB_BUCKET/" \
    --region "$REGION" \
    --delete \
    --cache-control "max-age=86400" \
    --exclude "*.map"

# Create CloudFront invalidation
DISTRIBUTION_ID=$(aws cloudformation describe-stacks \
    --stack-name "$INFRASTRUCTURE_STACK" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDistributionId`].OutputValue' \
    --output text)

aws cloudfront create-invalidation \
    --distribution-id "$DISTRIBUTION_ID" \
    --paths "/*" \
    --region "$REGION" >/dev/null

echo -e "${GREEN}✅ Web content deployed${NC}"

# Step 6: Wait for ECS Service to be Stable
echo -e "${BLUE}Step 6: Waiting for ECS service to be stable...${NC}"
ECS_CLUSTER=$(aws cloudformation describe-stacks \
    --stack-name "$ECS_STACK" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`ECSClusterName`].OutputValue' \
    --output text)

ECS_SERVICE=$(aws cloudformation describe-stacks \
    --stack-name "$ECS_STACK" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`ECSServiceName`].OutputValue' \
    --output text)

echo "Waiting for ECS service to stabilize (this may take a few minutes)..."
aws ecs wait services-stable \
    --cluster "$ECS_CLUSTER" \
    --services "$ECS_SERVICE" \
    --region "$REGION"

echo -e "${GREEN}✅ ECS service is stable${NC}"

# Save deployment info
cat > "$PROJECT_ROOT/deployment-info.json" << EOF
{
    "environment": "$ENVIRONMENT",
    "region": "$REGION",
    "infrastructure_stack": "$INFRASTRUCTURE_STACK",
    "ecs_stack": "$ECS_STACK",
    "cloudfront_domain": "$CLOUDFRONT_DOMAIN",
    "web_bucket": "$WEB_BUCKET",
    "stream_bucket": "$STREAM_BUCKET",
    "ecr_repository": "$ECR_URI",
    "ecs_cluster": "$ECS_CLUSTER",
    "ecs_service": "$ECS_SERVICE",
    "distribution_id": "$DISTRIBUTION_ID",
    "deployed_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

echo ""
echo -e "${GREEN}🎉 Complete deployment finished successfully!${NC}"
echo ""
echo -e "${BLUE}Access your emulator at:${NC}"
if [ ! -z "$DOMAIN_NAME" ]; then
    echo "  https://$DOMAIN_NAME"
else
    echo "  https://$CLOUDFRONT_DOMAIN"
fi
echo ""
echo -e "${BLUE}Deployment Summary:${NC}"
echo "  • Infrastructure Stack: $INFRASTRUCTURE_STACK"
echo "  • ECS Stack: $ECS_STACK"
echo "  • Docker Image: $ECR_URI:$ENVIRONMENT"
echo "  • ECS Cluster: $ECS_CLUSTER"
echo "  • ECS Service: $ECS_SERVICE"
echo ""
echo -e "${BLUE}Monitoring:${NC}"
echo "  • ECS Console: https://$REGION.console.aws.amazon.com/ecs/home?region=$REGION#/clusters/$ECS_CLUSTER/services"
echo "  • CloudFront Console: https://console.aws.amazon.com/cloudfront/home#/distributions/$DISTRIBUTION_ID"
echo "  • CloudWatch Logs: https://$REGION.console.aws.amazon.com/cloudwatch/home?region=$REGION#logsV2:log-groups/log-group/%252Fecs%252Fspectrum-emulator-$ENVIRONMENT"
echo ""
echo -e "${YELLOW}Note: It may take a few minutes for all services to be fully operational${NC}"
