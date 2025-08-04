# ZX Spectrum Emulator - Quick Reference Guide

## 🚀 **Quick Start**

```bash
# 1. Clone and setup
git clone <your-repo-url>
cd SpeccyEmulator
cp .env.template .env
# Edit .env with your AWS account details

# 2. Deploy everything
./scripts/complete-setup.sh

# 3. Access your emulator
# Web interface will be displayed at the end of setup
```

## 🔧 **Common Operations**

### Check Service Status
```bash
# ECS service status
aws ecs describe-services \
    --cluster spectrum-emulator-cluster-dev \
    --services spectrum-youtube-streaming

# Container health
aws elbv2 describe-target-health \
    --target-group-arn $(aws elbv2 describe-target-groups \
        --names spectrum-api-tg-dev \
        --query 'TargetGroups[0].TargetGroupArn' --output text)
```

### View Logs
```bash
# Real-time container logs
aws logs tail "/ecs/spectrum-emulator-streaming" --follow

# Search for errors
aws logs filter-log-events \
    --log-group-name "/ecs/spectrum-emulator-streaming" \
    --filter-pattern "ERROR"

# Search for specific patterns
aws logs filter-log-events \
    --log-group-name "/ecs/spectrum-emulator-streaming" \
    --filter-pattern "FUSE emulator"
```

### Update Docker Image
```bash
# Build new image
docker build -f complete-emulator.dockerfile -t spectrum-emulator:new-version .

# Tag and push to ECR
docker tag spectrum-emulator:new-version \
    ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/spectrum-emulator:new-version

docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/spectrum-emulator:new-version

# Update task definition (edit image URI in task definition file)
aws ecs register-task-definition \
    --cli-input-json file://aws/task-definition-complete-fix.json

# Update service with new task definition
aws ecs update-service \
    --cluster spectrum-emulator-cluster-dev \
    --service spectrum-youtube-streaming \
    --task-definition spectrum-emulator-streaming:NEW_REVISION
```

### Scale Service
```bash
# Scale up
aws ecs update-service \
    --cluster spectrum-emulator-cluster-dev \
    --service spectrum-youtube-streaming \
    --desired-count 2

# Scale down
aws ecs update-service \
    --cluster spectrum-emulator-cluster-dev \
    --service spectrum-youtube-streaming \
    --desired-count 0
```

### Update Web Content
```bash
# Upload new web files
aws s3 sync web/ s3://spectrum-emulator-web-dev-${AWS_ACCOUNT_ID}/ \
    --delete \
    --cache-control "max-age=86400"

# Invalidate CloudFront cache
DISTRIBUTION_ID=$(aws cloudfront list-distributions \
    --query 'DistributionList.Items[?Comment==`ZX Spectrum Emulator Distribution`].Id' \
    --output text)

aws cloudfront create-invalidation \
    --distribution-id $DISTRIBUTION_ID \
    --paths "/*"
```

## 🐛 **Troubleshooting**

### Container Won't Start
```bash
# Check ECS service events
aws ecs describe-services \
    --cluster spectrum-emulator-cluster-dev \
    --services spectrum-youtube-streaming \
    --query 'services[0].events'

# Check task definition
aws ecs describe-task-definition \
    --task-definition spectrum-emulator-streaming

# Check container logs for startup errors
aws logs tail "/ecs/spectrum-emulator-streaming" --follow
```

### WebSocket Connection Issues
```bash
# Test WebSocket endpoint
curl -v --no-buffer \
    --header "Connection: Upgrade" \
    --header "Upgrade: websocket" \
    --header "Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==" \
    --header "Sec-WebSocket-Version: 13" \
    https://YOUR_CLOUDFRONT_DOMAIN/ws/

# Check ALB target group health
aws elbv2 describe-target-health \
    --target-group-arn $(aws elbv2 describe-target-groups \
        --names spectrum-ws-tg-dev \
        --query 'TargetGroups[0].TargetGroupArn' --output text)
```

### Video Stream Not Working
```bash
# Check HLS manifest
curl -s https://YOUR_CLOUDFRONT_DOMAIN/hls/stream.m3u8

# Check S3 bucket contents
aws s3 ls s3://spectrum-emulator-stream-dev-${AWS_ACCOUNT_ID}/hls/

# Check FFmpeg process in logs
aws logs filter-log-events \
    --log-group-name "/ecs/spectrum-emulator-streaming" \
    --filter-pattern "ffmpeg"
```

### Button Presses Not Working
```bash
# Check for FUSE emulator startup
aws logs filter-log-events \
    --log-group-name "/ecs/spectrum-emulator-streaming" \
    --filter-pattern "FUSE emulator"

# Check for X11 display issues
aws logs filter-log-events \
    --log-group-name "/ecs/spectrum-emulator-streaming" \
    --filter-pattern "Xvfb"

# Check for SDL graphics context errors
aws logs filter-log-events \
    --log-group-name "/ecs/spectrum-emulator-streaming" \
    --filter-pattern "SDL graphics context"
```

## 📊 **Monitoring**

### Key Metrics to Watch
```bash
# ECS service metrics
aws cloudwatch get-metric-statistics \
    --namespace AWS/ECS \
    --metric-name CPUUtilization \
    --dimensions Name=ServiceName,Value=spectrum-youtube-streaming Name=ClusterName,Value=spectrum-emulator-cluster-dev \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Average

# ALB metrics
aws cloudwatch get-metric-statistics \
    --namespace AWS/ApplicationELB \
    --metric-name RequestCount \
    --dimensions Name=LoadBalancer,Value=app/spectrum-emulator-alb-dev/LOAD_BALANCER_ID \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Sum
```

### Health Check Endpoints
```bash
# Container health
curl -f https://YOUR_CLOUDFRONT_DOMAIN/health

# Direct ALB health (if accessible)
curl -f http://YOUR_ALB_DNS/health
```

## 🧹 **Cleanup**

### Complete Cleanup
```bash
# Remove all AWS resources
./scripts/cleanup.sh
```

### Partial Cleanup
```bash
# Stop service only
aws ecs update-service \
    --cluster spectrum-emulator-cluster-dev \
    --service spectrum-youtube-streaming \
    --desired-count 0

# Delete service but keep infrastructure
aws ecs delete-service \
    --cluster spectrum-emulator-cluster-dev \
    --service spectrum-youtube-streaming
```

## 🔐 **Security**

### Update IAM Policies
```bash
# View current policy
aws iam get-role-policy \
    --role-name ecsTaskExecutionRole \
    --policy-name SpectrumEmulatorS3Policy

# Update policy (edit aws/s3-access-policy.json first)
aws iam put-role-policy \
    --role-name ecsTaskExecutionRole \
    --policy-name SpectrumEmulatorS3Policy \
    --policy-document file://aws/s3-access-policy.json
```

### Rotate YouTube Stream Key
```bash
# Update environment variable in task definition
# Edit aws/task-definition-complete-fix.json
# Then register new task definition and update service
```

## 📝 **Configuration Files**

- `.env` - Environment variables and AWS configuration
- `aws/task-definition-complete-fix.json` - ECS task definition
- `complete-emulator.dockerfile` - Docker image build instructions
- `web/js/config.js` - Frontend configuration
- `fix-emulator-integration.py` - Main server application

## 🆘 **Emergency Procedures**

### Service Down
```bash
# Quick restart
aws ecs update-service \
    --cluster spectrum-emulator-cluster-dev \
    --service spectrum-youtube-streaming \
    --force-new-deployment

# Rollback to previous task definition
aws ecs update-service \
    --cluster spectrum-emulator-cluster-dev \
    --service spectrum-youtube-streaming \
    --task-definition spectrum-emulator-streaming:PREVIOUS_REVISION
```

### High CPU/Memory
```bash
# Scale up resources (edit task definition)
# Increase CPU from 1024 to 2048, memory from 2048 to 4096
# Register new task definition and update service
```

### Complete System Recovery
```bash
# If everything fails, redeploy from scratch
./scripts/cleanup.sh
./scripts/complete-setup.sh
```

---

## 📞 **Support**

For issues not covered in this guide:
1. Check container logs first: `aws logs tail "/ecs/spectrum-emulator-streaming" --follow`
2. Verify service health: Check ECS service status and target group health
3. Test individual components: WebSocket, HLS stream, health endpoint
4. Review recent changes: Check if any configuration was modified

Remember: The emulator is fully interactive with working button presses when properly deployed! 🎮
