# ZX Spectrum Emulator v7 Deployment Guide

## 🚀 **Quick Deployment**

### **Current Production Status**
- **Version**: v7-complete (1.0.0-v7-complete)
- **Status**: ✅ **FULLY OPERATIONAL** - Both backend and frontend deployed
- **URL**: https://d112s3ps8xh739.cloudfront.net
- **Backend**: ECS Task Definition 34 with v7-complete Docker image
- **Frontend**: S3 files updated 19:50:53 UTC, CloudFront cache invalidated
- **Features**: Mouse support, cursor hiding, virtual keyboard fixes, video scaling

---

## 🐳 **Docker Image Management**

### **Available Images**
```bash
# Latest v7 complete image
043309319786.dkr.ecr.us-east-1.amazonaws.com/spectrum-emulator:v7-complete

# Previous versions
043309319786.dkr.ecr.us-east-1.amazonaws.com/spectrum-emulator:v6-scaling-youtube
043309319786.dkr.ecr.us-east-1.amazonaws.com/spectrum-emulator:fixed-v5
```

### **Building New Version**
```bash
# Build locally
docker build -f fixed-emulator-v5.dockerfile -t spectrum-emulator:v7-complete .

# Tag for ECR
docker tag spectrum-emulator:v7-complete \
  043309319786.dkr.ecr.us-east-1.amazonaws.com/spectrum-emulator:v7-complete

# Push to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  043309319786.dkr.ecr.us-east-1.amazonaws.com

docker push 043309319786.dkr.ecr.us-east-1.amazonaws.com/spectrum-emulator:v7-complete
```

---

## ⚙️ **ECS Deployment**

### **Current Configuration**
- **Cluster**: spectrum-emulator-cluster-dev
- **Service**: spectrum-youtube-streaming
- **Task Definition**: spectrum-emulator-streaming:34
- **CPU**: 1024
- **Memory**: 2048 MB

### **Deploy New Version**
```bash
# Create new task definition
aws ecs register-task-definition --cli-input-json file://task-definition-v7.json

# Update service
aws ecs update-service \
  --cluster spectrum-emulator-cluster-dev \
  --service spectrum-youtube-streaming \
  --task-definition spectrum-emulator-streaming:NEW_REVISION
```

### **Monitor Deployment**
```bash
# Check service status
aws ecs describe-services \
  --cluster spectrum-emulator-cluster-dev \
  --services spectrum-youtube-streaming

# View logs
aws logs tail "/ecs/spectrum-emulator-streaming" --follow
```

---

## 🔧 **Environment Configuration**

### **Required Environment Variables**
```bash
DISPLAY=:99                    # Virtual X11 display
SDL_VIDEODRIVER=x11           # Graphics driver
SDL_AUDIODRIVER=pulse         # Audio driver
PULSE_RUNTIME_PATH=/tmp/pulse  # Audio runtime path
STREAM_BUCKET=spectrum-emulator-stream-dev-043309319786
CAPTURE_SIZE=256x192          # Native ZX Spectrum resolution
DISPLAY_SIZE=256x192          # Match capture size
CAPTURE_OFFSET=0,0            # Video capture offset
SCALE_FACTOR=2                # 2x scaling for output
YOUTUBE_STREAM_KEY=***        # YouTube RTMP key
```

### **Task Definition Template**
```json
{
  "family": "spectrum-emulator-streaming",
  "taskRoleArn": "arn:aws:iam::043309319786:role/ecsTaskExecutionRole",
  "executionRoleArn": "arn:aws:iam::043309319786:role/ecsTaskExecutionRole",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "1024",
  "memory": "2048",
  "containerDefinitions": [{
    "name": "spectrum-emulator-streamer",
    "image": "043309319786.dkr.ecr.us-east-1.amazonaws.com/spectrum-emulator:v7-complete",
    "essential": true,
    "portMappings": [
      {"containerPort": 8080, "protocol": "tcp"},
      {"containerPort": 8765, "protocol": "tcp"}
    ],
    "environment": [
      {"name": "DISPLAY", "value": ":99"},
      {"name": "CAPTURE_SIZE", "value": "256x192"},
      {"name": "SCALE_FACTOR", "value": "2"},
      {"name": "YOUTUBE_STREAM_KEY", "value": "***"}
    ],
    "healthCheck": {
      "command": ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"],
      "interval": 30,
      "timeout": 10,
      "retries": 3,
      "startPeriod": 120
    }
  }]
}
```

---

## 🌐 **Frontend Deployment**

### **Static Files**
Upload to S3 bucket: `spectrum-emulator-web-dev-043309319786`

```bash
# Sync web files
aws s3 sync web/ s3://spectrum-emulator-web-dev-043309319786/ \
  --exclude "*.md" --exclude "node_modules/*"

# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id E39XTPIC2OU0Y2 \
  --paths "/*"
```

### **v7 Frontend Files Deployed (August 2, 2025)**
- ✅ `index.html` (16,716 bytes) - Video scaling fixes, mouse support UI
- ✅ `js/spectrum-emulator.js` (20,450 bytes) - Mouse event handlers, virtual keyboard fixes
- ✅ `css/spectrum.css` (8,596 bytes) - Updated styling
- ✅ **CloudFront Invalidation**: I9LX73QV339TS4JA82CR4I5EZR (completed)

### **Key Frontend Features in v7**
- **Video Container**: Proper 4:3 aspect ratio, 512px max-width
- **Mouse Support**: Click event listeners on video player with coordinate mapping
- **Virtual Keyboard**: Click-only behavior, no hover activation
- **Responsive Design**: Mobile-friendly scaling
- **Visual Feedback**: Crosshair cursor on interactive video

---

## 🔍 **Health Monitoring**

### **Health Check Endpoints**
```bash
# Main health check
curl https://d112s3ps8xh739.cloudfront.net/health

# Expected v7 response
{
  "status": "OK",
  "version": {
    "version": "1.0.0-v7-complete",
    "build_hash": "v7-mouse-cursor-keyboard-fixes"
  },
  "emulator_running": true,
  "youtube_streaming": true,
  "features": [
    "interactive_keys",
    "real_time_feedback", 
    "key_press_and_release",
    "mouse_support",
    "youtube_streaming"
  ]
}
```

### **Monitoring Commands**
```bash
# Check ECS service health
aws ecs describe-services \
  --cluster spectrum-emulator-cluster-dev \
  --services spectrum-youtube-streaming \
  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}'

# Test WebSocket connection
curl -v --no-buffer \
  --header "Connection: Upgrade" \
  --header "Upgrade: websocket" \
  https://d112s3ps8xh739.cloudfront.net/ws/

# Test video stream
curl -s "https://spectrum-emulator-stream-dev-043309319786.s3.us-east-1.amazonaws.com/hls/stream.m3u8"
```

---

## 🚨 **Troubleshooting**

### **Common Issues**

**1. Container Health Check Failures**
```bash
# Check container logs
aws logs tail "/ecs/spectrum-emulator-streaming" --follow

# Common causes:
# - Xvfb failed to start
# - FUSE emulator SDL context error
# - FFmpeg capture issues
```

**2. Mouse Input Not Working**
```bash
# Verify xdotool is installed in container
# Check WebSocket message format:
{
  "type": "mouse_click",
  "button": "left",
  "x": 128,
  "y": 96
}
```

**3. Video Stream Issues**
```bash
# Check FFmpeg processes
# Verify S3 bucket permissions
# Confirm HLS segment generation
```

### **Rollback Procedure**
```bash
# Rollback to previous version
aws ecs update-service \
  --cluster spectrum-emulator-cluster-dev \
  --service spectrum-youtube-streaming \
  --task-definition spectrum-emulator-streaming:33  # Previous revision
```

---

## ✅ **Deployment Checklist**

### **Pre-deployment**
- [ ] Docker image built and tested locally
- [ ] ECR image pushed successfully
- [ ] Task definition JSON validated
- [ ] Environment variables configured
- [ ] Health check endpoints verified

### **Deployment**
- [ ] Task definition registered
- [ ] ECS service updated
- [ ] Health checks passing
- [ ] WebSocket connection working
- [ ] Video stream accessible
- [ ] Mouse input functional
- [ ] YouTube stream active (if configured)

### **Post-deployment**
- [ ] Frontend files updated (if needed)
- [ ] CloudFront cache invalidated
- [ ] Monitoring alerts configured
- [ ] Documentation updated
- [ ] Team notified of new features

---

## 🎯 **Performance Expectations**

### **Deployment Metrics**
- **Success Rate**: 95%+ with pre-built images
- **Startup Time**: 30-60 seconds
- **Health Check Grace**: 120 seconds
- **Resource Usage**: 1024 CPU / 2048 MB

### **Runtime Performance**
- **Video Latency**: ~2-3 seconds
- **Input Response**: <100ms
- **Stream Quality**: 2.5Mbps video, 128k audio
- **Uptime**: 99%+ with ECS Fargate

The v7 deployment provides a complete, professional-grade ZX Spectrum emulator experience with mouse support, cursor-free video streams, and enhanced user interaction! 🎮
