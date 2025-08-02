# ZX Spectrum Emulator with YouTube Live Streaming

A complete web-based ZX Spectrum emulator with real-time YouTube streaming and authentic keyboard interface.

## 🎮 **LIVE DEMO**

**🌐 Web Control Interface:** https://d112s3ps8xh739.cloudfront.net/youtube-stream-control.html

**📺 YouTube Stream:** Your ZX Spectrum emulator streams live to YouTube with key `0ebh-efdh-9qtq-2eq3-e6hz`

## 🚀 **Quick Start - Stream to YouTube Now!**

### **Option 1: Use Web Interface (Recommended)**
1. **Open:** https://d112s3ps8xh739.cloudfront.net/youtube-stream-control.html
2. **Click:** "Connect to Server"
3. **Click:** "🚀 Start YouTube Stream"
4. **Check:** Your YouTube Live dashboard - stream should appear in 30-60 seconds!

### **Option 2: Use Command Line Scripts**
```bash
# Start streaming to YouTube
./start-youtube-stream.sh

# Stop streaming
./stop-youtube-stream.sh

# Check status
aws ecs describe-services --cluster spectrum-emulator-cluster-dev --services spectrum-emulator-streaming-service --region us-east-1
```

## 📊 **Current Status: READY TO STREAM! 🔴**

### ✅ **What's Working:**
- ✅ **YouTube Streaming:** Configured with your stream key `0ebh-efdh-9qtq-2eq3-e6hz`
- ✅ **Web Control Interface:** Full remote control via browser
- ✅ **ZX Spectrum Emulator:** FUSE emulator with authentic 48K experience
- ✅ **AWS Infrastructure:** CloudFront + ECS + Load Balancer
- ✅ **WebSocket Control:** Real-time communication
- ✅ **Video Pipeline:** FFmpeg → RTMP → YouTube Live

### 🎯 **Stream Configuration:**
- **Platform:** YouTube Live
- **Stream Key:** `0ebh-efdh-9qtq-2eq3-e6hz`
- **RTMP URL:** `rtmp://a.rtmp.youtube.com/live2`
- **Resolution:** 512x384 (authentic ZX Spectrum)
- **Bitrate:** 2.5 Mbps H.264 + 128k AAC audio
- **Frame Rate:** 25 FPS

## 🎮 **What You'll Stream**

When you start the stream, viewers will see:
- **ZX Spectrum 48K emulator** running authentic software
- **Boot sequence** and classic ZX Spectrum interface
- **Manic Miner** game pre-loaded (classic ZX Spectrum game)
- **Real-time audio** from the emulator
- **Authentic display** at original resolution

## 🌐 **Web Control Interface**

### **Main Control Page**
**URL:** https://d112s3ps8xh739.cloudfront.net/youtube-stream-control.html

**Features:**
- 🔌 **WebSocket Connection Status**
- 📺 **YouTube Stream Configuration Display**
- 🚀 **Start/Stop Streaming Controls**
- 📊 **Real-time Status Updates**
- 📋 **Activity Log**

### **Other Available Pages**
- **Main Interface:** https://d112s3ps8xh739.cloudfront.net
- **WebSocket Test:** https://d112s3ps8xh739.cloudfront.net/test-websocket.html

## 🔧 **Architecture Overview**

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Web Browser   │───▶│   CloudFront     │───▶│  YouTube Live   │
│  Control Panel  │    │   Distribution   │    │   Streaming     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                        │                       ▲
         │ WebSocket              │ HTTPS                 │ RTMP
         ▼                        ▼                       │
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   ECS Fargate   │◀───│ Application      │    │     FFmpeg      │
│  ZX Spectrum    │    │ Load Balancer    │    │   Streaming     │
│   Emulator      │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 📋 **Monitoring Your Stream**

### **AWS Console Monitoring**
1. **ECS Service:** `ECS → Clusters → spectrum-emulator-cluster-dev → Services → spectrum-emulator-streaming-service`
2. **CloudWatch Logs:** `CloudWatch → Log Groups → /ecs/spectrum-emulator-streaming`
3. **Load Balancer:** `EC2 → Load Balancers → spectrum-emulator-alb-dev`

### **Command Line Monitoring**
```bash
# Check service status
aws ecs describe-services --cluster spectrum-emulator-cluster-dev --services spectrum-emulator-streaming-service --region us-east-1

# View streaming logs
aws logs tail "/ecs/spectrum-emulator-streaming" --follow --region us-east-1

# Test health endpoint
curl "http://spectrum-emulator-alb-dev-1273339161.us-east-1.elb.amazonaws.com/health"
```

## 🛠️ **Technical Details**

### **Current Deployment**
- **ECS Cluster:** `spectrum-emulator-cluster-dev`
- **Service:** `spectrum-emulator-streaming-service`
- **Task Definition:** `spectrum-emulator-streaming:3` (YouTube-enabled)
- **CloudFront:** `d112s3ps8xh739.cloudfront.net`
- **Region:** `us-east-1`

### **Container Configuration**
- **Image:** `ubuntu:22.04`
- **CPU:** 2048 (2 vCPU)
- **Memory:** 4096 MB (4 GB)
- **Ports:** 8080 (HTTP), 8765 (WebSocket)

### **Environment Variables**
```bash
DISPLAY=:99
YOUTUBE_RTMP_KEY=0ebh-efdh-9qtq-2eq3-e6hz
TWITCH_RTMP_KEY=DISABLED
```

## 🎉 **Ready to Stream!**

Your ZX Spectrum emulator is fully configured and ready to stream to YouTube Live!

**🚀 Start streaming now:**
1. **Open:** https://d112s3ps8xh739.cloudfront.net/youtube-stream-control.html
2. **Click:** "Connect to Server"
3. **Click:** "🚀 Start YouTube Stream"
4. **Watch:** Your YouTube Live dashboard for the stream to appear

**📺 Stream Details:**
- **YouTube Key:** `0ebh-efdh-9qtq-2eq3-e6hz`
- **Resolution:** 512x384 (authentic ZX Spectrum)
- **Content:** ZX Spectrum 48K emulator with Manic Miner
- **Audio:** Full ZX Spectrum sound effects and music

**The retro gaming nostalgia starts now! 🎮✨**
