#!/bin/bash

# ZX Spectrum Emulator - Complete Setup Script
# This script automates the entire infrastructure deployment

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check if .env file exists
if [ ! -f .env ]; then
    error ".env file not found. Please copy .env.template to .env and configure your values."
fi

# Load environment variables
source .env

# Validate required variables
required_vars=("AWS_ACCOUNT_ID" "AWS_REGION" "PROJECT_NAME" "ENVIRONMENT")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        error "Required environment variable $var is not set"
    fi
done

log "Starting ZX Spectrum Emulator deployment..."
log "AWS Account: $AWS_ACCOUNT_ID"
log "Region: $AWS_REGION"
log "Environment: $ENVIRONMENT"

# Step 1: Verify AWS CLI access
log "Verifying AWS CLI access..."
aws sts get-caller-identity > /dev/null || error "AWS CLI not configured or no access"
success "AWS CLI access verified"

# Step 2: Create VPC and networking
log "Creating VPC and networking infrastructure..."
./scripts/setup-vpc.sh
success "VPC and networking created"

# Step 3: Create S3 buckets
log "Creating S3 buckets..."
./scripts/setup-s3.sh
success "S3 buckets created"

# Step 4: Setup ECR and build Docker image
log "Setting up ECR and building Docker image..."
./scripts/setup-ecr.sh
success "Docker image built and pushed to ECR"

# Step 5: Create IAM roles
log "Creating IAM roles..."
./scripts/setup-iam.sh
success "IAM roles created"

# Step 6: Create ECS cluster and task definition
log "Setting up ECS cluster..."
./scripts/setup-ecs.sh
success "ECS cluster and task definition created"

# Step 7: Create Load Balancer
log "Creating Application Load Balancer..."
./scripts/setup-alb.sh
success "Load Balancer created"

# Step 8: Create CloudFront distribution
log "Creating CloudFront distribution..."
./scripts/setup-cloudfront.sh
success "CloudFront distribution created"

# Step 9: Deploy ECS service
log "Deploying ECS service..."
./scripts/deploy-service.sh
success "ECS service deployed"

# Step 10: Upload web content
log "Uploading web content..."
./scripts/upload-web-content.sh
success "Web content uploaded"

# Step 11: Wait for service to be healthy
log "Waiting for service to become healthy..."
./scripts/wait-for-health.sh
success "Service is healthy and ready"

# Get final URLs
CLOUDFRONT_DOMAIN=$(aws cloudfront list-distributions \
    --query 'DistributionList.Items[?Comment==`ZX Spectrum Emulator Distribution`].DomainName' \
    --output text)

ALB_DNS=$(aws elbv2 describe-load-balancers \
    --names spectrum-emulator-alb-${ENVIRONMENT} \
    --query 'LoadBalancers[0].DNSName' --output text)

# Display completion message
echo ""
echo "=========================================="
echo "🎉 DEPLOYMENT COMPLETE! 🎉"
echo "=========================================="
echo ""
echo "Your ZX Spectrum Emulator is now live at:"
echo "🌐 Web Interface: https://$CLOUDFRONT_DOMAIN"
echo "📺 YouTube Control: https://$CLOUDFRONT_DOMAIN/youtube-stream-control.html"
echo ""
echo "Infrastructure Details:"
echo "🔗 CloudFront Domain: $CLOUDFRONT_DOMAIN"
echo "⚖️  Load Balancer: $ALB_DNS"
echo "🐳 ECS Cluster: spectrum-emulator-cluster-${ENVIRONMENT}"
echo "📦 ECR Repository: ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/spectrum-emulator"
echo ""
echo "Monitoring:"
echo "📊 ECS Service: aws ecs describe-services --cluster spectrum-emulator-cluster-${ENVIRONMENT} --services spectrum-youtube-streaming"
echo "📋 Container Logs: aws logs tail \"/ecs/spectrum-emulator-streaming\" --follow --region ${AWS_REGION}"
echo ""
echo "🎮 The emulator should be fully interactive with working button presses!"
echo "=========================================="

# Save deployment info
cat > deployment-info.txt << EOF
ZX Spectrum Emulator Deployment Information
==========================================

Deployment Date: $(date)
AWS Account: $AWS_ACCOUNT_ID
Region: $AWS_REGION
Environment: $ENVIRONMENT

URLs:
- Web Interface: https://$CLOUDFRONT_DOMAIN
- YouTube Control: https://$CLOUDFRONT_DOMAIN/youtube-stream-control.html

Infrastructure:
- CloudFront Domain: $CLOUDFRONT_DOMAIN
- Load Balancer: $ALB_DNS
- ECS Cluster: spectrum-emulator-cluster-${ENVIRONMENT}
- ECR Repository: ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/spectrum-emulator

Monitoring Commands:
- Service Status: aws ecs describe-services --cluster spectrum-emulator-cluster-${ENVIRONMENT} --services spectrum-youtube-streaming
- Container Logs: aws logs tail "/ecs/spectrum-emulator-streaming" --follow --region ${AWS_REGION}
- Health Check: curl -f https://$CLOUDFRONT_DOMAIN/health

Cleanup Command:
- ./scripts/cleanup.sh
EOF

success "Deployment information saved to deployment-info.txt"
log "Setup complete! 🚀"
