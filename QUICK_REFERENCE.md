# ZX Spectrum Emulator - Quick Reference

## 🚀 **Live URLs**
- **Web Interface**: https://d112s3ps8xh739.cloudfront.net
- **YouTube Control**: https://d112s3ps8xh739.cloudfront.net/youtube-stream-control.html
- **WebSocket**: `wss://d112s3ps8xh739.cloudfront.net/ws/`

## 🔧 **Current Services**

### Active YouTube Streaming Service
```bash
Service Name: spectrum-youtube-streaming
Cluster: spectrum-emulator-cluster-dev
Task Definition: spectrum-emulator-streaming:3
Status: ACTIVE (1/1 running)
```

### Inactive Legacy Service
```bash
Service Name: spectrum-emulator-service-dev
Cluster: spectrum-emulator-cluster-dev
Task Definition: spectrum-emulator-dev:16
Status: ACTIVE (0/1 running) - Scaled down
```

## 📊 **Monitoring Commands**

### Check Service Status
```bash
# YouTube streaming service
aws ecs describe-services --cluster spectrum-emulator-cluster-dev --services spectrum-youtube-streaming --region us-east-1

# Legacy service (should show 0 running)
aws ecs describe-services --cluster spectrum-emulator-cluster-dev --services spectrum-emulator-service-dev --region us-east-1
```

### View Logs
```bash
# Streaming service logs
aws logs tail "/ecs/spectrum-emulator-streaming" --follow --region us-east-1

# Legacy service logs (if needed)
aws logs tail "/ecs/spectrum-emulator-dev" --follow --region us-east-1
```

### Test Endpoints
```bash
# Test WebSocket
curl -v --no-buffer \
  --header "Connection: Upgrade" \
  --header "Upgrade: websocket" \
  --header "Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==" \
  --header "Sec-WebSocket-Version: 13" \
  https://d112s3ps8xh739.cloudfront.net/ws/

# Test video stream
curl -s "https://spectrum-emulator-stream-dev-043309319786.s3.us-east-1.amazonaws.com/hls/stream.m3u8"

# Test web interface
curl -I https://d112s3ps8xh739.cloudfront.net
```

## 🎥 **YouTube Streaming**

### Configuration
- **Stream Key**: `0ebh-efdh-9qtq-2eq3-e6hz`
- **RTMP URL**: `rtmp://a.rtmp.youtube.com/live2`
- **Status**: ✅ **LIVE**

### Control Interface
Access the YouTube streaming controls at:
https://d112s3ps8xh739.cloudfront.net/youtube-stream-control.html

## 🔄 **Service Management**

### Scale YouTube Service
```bash
# Scale up (normal operation)
aws ecs update-service --cluster spectrum-emulator-cluster-dev \
  --service spectrum-youtube-streaming --desired-count 1

# Scale down (maintenance)
aws ecs update-service --cluster spectrum-emulator-cluster-dev \
  --service spectrum-youtube-streaming --desired-count 0
```

### Emergency Rollback
```bash
# If YouTube service fails, rollback to legacy service
aws ecs update-service --cluster spectrum-emulator-cluster-dev \
  --service spectrum-youtube-streaming --desired-count 0

aws ecs update-service --cluster spectrum-emulator-cluster-dev \
  --service spectrum-emulator-service-dev --desired-count 1
```

## 📁 **S3 Buckets**
- **Web Content**: `spectrum-emulator-web-dev-043309319786`
- **Video Stream**: `spectrum-emulator-stream-dev-043309319786`

## 🌐 **CloudFront**
- **Distribution ID**: `d112s3ps8xh739.cloudfront.net`
- **Behaviors**: 
  - `/` → S3 web content
  - `/ws/` → ALB WebSocket
  - `/api/` → ALB API

## 🏗️ **Infrastructure**
- **Region**: us-east-1
- **ECS Cluster**: spectrum-emulator-cluster-dev
- **Load Balancer**: spectrum-emulator-alb-dev
- **Target Groups**: 
  - spectrum-api-tg-dev (port 8080)
  - spectrum-ws-tg-dev (port 8765)

## 🎮 **Usage**
1. Open https://d112s3ps8xh739.cloudfront.net
2. Wait for video stream to load
3. Click "Start Emulator" to send WebSocket command
4. Monitor YouTube stream via control interface
5. Use on-screen keyboard for input (when implemented)

---
**Last Updated**: August 2, 2025  
**Status**: ✅ **FULLY OPERATIONAL**
