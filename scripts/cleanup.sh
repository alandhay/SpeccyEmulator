#!/bin/bash

# ZX Spectrum Emulator - Cleanup Script
# This script removes all AWS resources created by the setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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
}

# Load environment variables
if [ -f .env ]; then
    source .env
else
    error ".env file not found"
fi

echo "=========================================="
echo "🧹 CLEANUP: ZX Spectrum Emulator"
echo "=========================================="
echo ""
warning "This will DELETE ALL AWS resources for the ZX Spectrum Emulator!"
echo "Environment: $ENVIRONMENT"
echo "AWS Account: $AWS_ACCOUNT_ID"
echo "Region: $AWS_REGION"
echo ""
read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirm

if [ "$confirm" != "yes" ]; then
    log "Cleanup cancelled"
    exit 0
fi

log "Starting cleanup process..."

# Step 1: Scale down ECS service
log "Scaling down ECS service..."
aws ecs update-service \
    --cluster spectrum-emulator-cluster-${ENVIRONMENT} \
    --service spectrum-youtube-streaming \
    --desired-count 0 \
    --region $AWS_REGION || warning "ECS service not found or already scaled down"

# Wait for tasks to stop
log "Waiting for tasks to stop..."
sleep 30

# Step 2: Delete ECS service
log "Deleting ECS service..."
aws ecs delete-service \
    --cluster spectrum-emulator-cluster-${ENVIRONMENT} \
    --service spectrum-youtube-streaming \
    --region $AWS_REGION || warning "ECS service not found"

# Step 3: Delete CloudFront distribution
log "Deleting CloudFront distribution..."
DISTRIBUTION_ID=$(aws cloudfront list-distributions \
    --query 'DistributionList.Items[?Comment==`ZX Spectrum Emulator Distribution`].Id' \
    --output text 2>/dev/null || echo "")

if [ ! -z "$DISTRIBUTION_ID" ]; then
    # Disable distribution first
    aws cloudfront get-distribution-config --id $DISTRIBUTION_ID > /tmp/dist-config.json
    jq '.DistributionConfig.Enabled = false' /tmp/dist-config.json > /tmp/dist-config-disabled.json
    ETAG=$(jq -r '.ETag' /tmp/dist-config.json)
    
    aws cloudfront update-distribution \
        --id $DISTRIBUTION_ID \
        --distribution-config file:///tmp/dist-config-disabled.json \
        --if-match $ETAG
    
    log "CloudFront distribution disabled, waiting for deployment..."
    aws cloudfront wait distribution-deployed --id $DISTRIBUTION_ID
    
    # Now delete it
    ETAG=$(aws cloudfront get-distribution --id $DISTRIBUTION_ID --query 'ETag' --output text)
    aws cloudfront delete-distribution --id $DISTRIBUTION_ID --if-match $ETAG
    success "CloudFront distribution deleted"
else
    warning "CloudFront distribution not found"
fi

# Step 4: Delete Load Balancer
log "Deleting Application Load Balancer..."
ALB_ARN=$(aws elbv2 describe-load-balancers \
    --names spectrum-emulator-alb-${ENVIRONMENT} \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text 2>/dev/null || echo "None")

if [ "$ALB_ARN" != "None" ]; then
    aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN --region $AWS_REGION
    success "Load Balancer deleted"
else
    warning "Load Balancer not found"
fi

# Step 5: Delete Target Groups
log "Deleting Target Groups..."
for tg_name in "spectrum-api-tg-${ENVIRONMENT}" "spectrum-ws-tg-${ENVIRONMENT}"; do
    TG_ARN=$(aws elbv2 describe-target-groups \
        --names $tg_name \
        --query 'TargetGroups[0].TargetGroupArn' \
        --output text 2>/dev/null || echo "None")
    
    if [ "$TG_ARN" != "None" ]; then
        aws elbv2 delete-target-group --target-group-arn $TG_ARN --region $AWS_REGION
        success "Target Group $tg_name deleted"
    else
        warning "Target Group $tg_name not found"
    fi
done

# Step 6: Delete ECS Cluster
log "Deleting ECS cluster..."
aws ecs delete-cluster \
    --cluster spectrum-emulator-cluster-${ENVIRONMENT} \
    --region $AWS_REGION || warning "ECS cluster not found"

# Step 7: Delete CloudWatch Log Group
log "Deleting CloudWatch log group..."
aws logs delete-log-group \
    --log-group-name "/ecs/spectrum-emulator-streaming" \
    --region $AWS_REGION || warning "Log group not found"

# Step 8: Empty and delete S3 buckets
log "Emptying and deleting S3 buckets..."
for bucket in "spectrum-emulator-web-${ENVIRONMENT}-${AWS_ACCOUNT_ID}" "spectrum-emulator-stream-${ENVIRONMENT}-${AWS_ACCOUNT_ID}"; do
    if aws s3 ls "s3://$bucket" >/dev/null 2>&1; then
        aws s3 rm "s3://$bucket" --recursive --region $AWS_REGION
        aws s3 rb "s3://$bucket" --region $AWS_REGION
        success "S3 bucket $bucket deleted"
    else
        warning "S3 bucket $bucket not found"
    fi
done

# Step 9: Delete ECR repository
log "Deleting ECR repository..."
aws ecr delete-repository \
    --repository-name spectrum-emulator \
    --force \
    --region $AWS_REGION || warning "ECR repository not found"

# Step 10: Delete Security Groups
log "Deleting Security Groups..."
VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=spectrum-emulator-vpc" \
    --query 'Vpcs[0].VpcId' \
    --output text 2>/dev/null || echo "None")

if [ "$VPC_ID" != "None" ]; then
    for sg_name in "spectrum-emulator-alb-sg" "spectrum-emulator-ecs-sg"; do
        SG_ID=$(aws ec2 describe-security-groups \
            --filters "Name=group-name,Values=$sg_name" \
            --query 'SecurityGroups[0].GroupId' \
            --output text 2>/dev/null || echo "None")
        
        if [ "$SG_ID" != "None" ]; then
            aws ec2 delete-security-group --group-id $SG_ID --region $AWS_REGION
            success "Security Group $sg_name deleted"
        else
            warning "Security Group $sg_name not found"
        fi
    done
fi

# Step 11: Delete VPC and networking
log "Deleting VPC and networking..."
if [ "$VPC_ID" != "None" ]; then
    # Delete subnets
    for subnet_name in "spectrum-emulator-subnet-1a" "spectrum-emulator-subnet-1b"; do
        SUBNET_ID=$(aws ec2 describe-subnets \
            --filters "Name=tag:Name,Values=$subnet_name" \
            --query 'Subnets[0].SubnetId' \
            --output text 2>/dev/null || echo "None")
        
        if [ "$SUBNET_ID" != "None" ]; then
            aws ec2 delete-subnet --subnet-id $SUBNET_ID --region $AWS_REGION
            success "Subnet $subnet_name deleted"
        fi
    done
    
    # Delete route table
    RT_ID=$(aws ec2 describe-route-tables \
        --filters "Name=tag:Name,Values=spectrum-emulator-rt" \
        --query 'RouteTables[0].RouteTableId' \
        --output text 2>/dev/null || echo "None")
    
    if [ "$RT_ID" != "None" ]; then
        aws ec2 delete-route-table --route-table-id $RT_ID --region $AWS_REGION
        success "Route table deleted"
    fi
    
    # Detach and delete Internet Gateway
    IGW_ID=$(aws ec2 describe-internet-gateways \
        --filters "Name=tag:Name,Values=spectrum-emulator-igw" \
        --query 'InternetGateways[0].InternetGatewayId' \
        --output text 2>/dev/null || echo "None")
    
    if [ "$IGW_ID" != "None" ]; then
        aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $AWS_REGION
        aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID --region $AWS_REGION
        success "Internet Gateway deleted"
    fi
    
    # Delete VPC
    aws ec2 delete-vpc --vpc-id $VPC_ID --region $AWS_REGION
    success "VPC deleted"
else
    warning "VPC not found"
fi

# Step 12: Delete IAM roles and policies
log "Deleting IAM roles and policies..."

# Detach policies from role
aws iam detach-role-policy \
    --role-name ecsTaskExecutionRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy \
    2>/dev/null || warning "Policy already detached"

aws iam detach-role-policy \
    --role-name ecsTaskExecutionRole \
    --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/SpectrumEmulatorS3Policy \
    2>/dev/null || warning "Policy already detached"

# Delete custom policy
aws iam delete-policy \
    --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/SpectrumEmulatorS3Policy \
    2>/dev/null || warning "Policy not found"

# Delete role
aws iam delete-role --role-name ecsTaskExecutionRole 2>/dev/null || warning "Role not found"

# Clean up temporary files
rm -f /tmp/dist-config*.json deployment-info.txt

echo ""
echo "=========================================="
echo "🧹 CLEANUP COMPLETE! 🧹"
echo "=========================================="
echo ""
success "All ZX Spectrum Emulator resources have been deleted"
echo ""
echo "Cleaned up resources:"
echo "✅ ECS Service and Cluster"
echo "✅ CloudFront Distribution"
echo "✅ Application Load Balancer"
echo "✅ Target Groups"
echo "✅ S3 Buckets"
echo "✅ ECR Repository"
echo "✅ VPC and Networking"
echo "✅ Security Groups"
echo "✅ IAM Roles and Policies"
echo "✅ CloudWatch Log Groups"
echo ""
log "Cleanup completed successfully! 🎉"
