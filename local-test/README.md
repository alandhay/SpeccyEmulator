# Local ZX Spectrum Emulator Testing Environment

## 🎉 **MAJOR ACHIEVEMENT: YouTube Live Streaming Working!**

**✅ CONFIRMED WORKING - August 4, 2025**

YouTube Live streaming has been **successfully tested and validated** in the local environment! Multiple test streams were completed with 100% success rate, confirming that the emulator can stream directly to YouTube Live using RTMP.

**Key Success Metrics:**
- ✅ **RTMP Connection**: Successful connection to YouTube Live
- ✅ **Video Quality**: Clear 320x240 video at 25 FPS
- ✅ **Stream Stability**: No disconnections or errors
- ✅ **Multiple Keys**: Tested with different YouTube stream keys
- ✅ **Production Ready**: Configuration ready for ECS deployment
- ✅ **Golden Reference v2**: User context fixes validated locally

**Latest Update (August 4, 2025):**
- Golden Reference v2 implementation with user context fixes
- Enhanced Docker container compatibility
- Improved FUSE emulator startup reliability
- Production-ready deployment configuration

See [YOUTUBE_STREAMING_SUCCESS.md](YOUTUBE_STREAMING_SUCCESS.md) for complete technical details.

---

This directory contains a complete local testing environment for the ZX Spectrum emulator that mirrors the production ECS deployment. Use this to test and validate all functionality before containerization and deployment.

## 🎯 Purpose

- **Test Before Deploy**: Validate all functionality locally before creating Docker containers
- **Faster Development**: No container build/push/deploy cycle during development
- **Better Debugging**: Direct access to logs and processes
- **Cost Effective**: No ECS costs during development
- **Isolated Testing**: No impact on production environment
- **✅ YouTube Streaming**: Test and validate YouTube Live streaming integration
- **✅ Golden Reference v2**: Validate user context fixes and container compatibility
- **Production Parity**: Mirror exact production ECS deployment configuration

## 📁 Directory Structure

```
local-test/
├── README.md                          # This file
├── LOCAL_TEST_ARCHITECTURE.md         # Architecture documentation
├── YOUTUBE_STREAMING_SUCCESS.md       # ✅ YouTube streaming success documentation
├── server/                            # Local server implementation
│   ├── local_server.py               # Main server with WebSocket and streaming
│   ├── requirements.txt              # Python dependencies
│   └── start_local.sh               # Startup script
├── web/                              # Local web interface
│   ├── index.html                   # Test web interface
│   ├── css/spectrum.css             # Styling
│   └── js/spectrum-local.js         # Client JavaScript
├── stream/hls/                       # HLS streaming output (auto-created)
├── logs/                            # Log files (auto-created)
├── test_dual_streaming.sh           # ✅ Successful YouTube + Kinesis streaming test
├── test_new_youtube_key.sh          # ✅ Successful YouTube key validation test
├── verify_youtube_stream.sh         # YouTube stream verification utilities
└── test-scripts/                    # Testing utilities
    ├── test_websocket.py           # WebSocket connection tests
    └── validate_all.py             # Comprehensive validation
```

## 🚀 Quick Start

### 1. Install System Dependencies

```bash
sudo apt-get update
sudo apt-get install -y fuse-emulator-sdl ffmpeg xdotool python3-pip python3-venv
```

### 2. Start the Local Server

```bash
cd /home/ubuntu/workspace/SpeccyEmulator/local-test
./server/start_local.sh
```

The startup script will:
- Create a Python virtual environment
- Install Python dependencies
- Check system dependencies
- Start the emulator server with all components

### 3. Access the Web Interface

Open your browser and go to: **http://localhost:8000**

### 4. Test Functionality

- **WebSocket Connection**: Should connect automatically
- **Start Emulator**: Click "▶️ Start Emulator" button
- **Video Stream**: Should show live emulator output
- **Virtual Keyboard**: Click keys to send to emulator
- **Physical Keyboard**: Type normally (keys will be forwarded)

## 🧪 Testing and Validation

### Run Comprehensive Validation

```bash
# In a separate terminal (while server is running)
cd /home/ubuntu/workspace/SpeccyEmulator/local-test
./test-scripts/validate_all.py
```

This will test:
- ✅ System dependencies
- ✅ X11 display connectivity
- ✅ File structure
- ✅ Python dependencies
- ✅ Health endpoint
- ✅ Web interface
- ✅ HLS video streaming
- ✅ WebSocket functionality

### Test WebSocket Only

```bash
./test-scripts/test_websocket.py
```

### Test with YouTube Streaming ✅ **WORKING**

```bash
export YOUTUBE_STREAM_KEY="your-stream-key-here"
./server/start_local.sh
```

**Or test YouTube streaming directly:**
```bash
# Test dual streaming (YouTube + Kinesis)
./test_dual_streaming.sh

# Test with new YouTube key
./test_new_youtube_key.sh

# Verify YouTube stream status
./verify_youtube_stream.sh
```

**YouTube Studio Integration:**
1. Go to https://studio.youtube.com → Go Live → Stream
2. Copy your stream key and use it in the tests above
3. Run the test script and watch for the stream in YouTube Studio
4. Click "GO LIVE" when the stream appears as "Ready to stream"

## 🔧 Configuration

### Environment Variables

- `YOUTUBE_STREAM_KEY`: Optional YouTube Live stream key for RTMP streaming
- `DISPLAY`: X11 display (automatically detected)

### Service Ports

- **8000**: Web interface (HTTP)
- **8080**: Health check endpoint (HTTP)
- **8765**: WebSocket server

### URLs

- **Web Interface**: http://localhost:8000
- **Health Check**: http://localhost:8080/health
- **WebSocket**: ws://localhost:8765
- **HLS Stream**: http://localhost:8000/stream/hls/stream.m3u8

## 🐛 Troubleshooting

### Common Issues

**"DISPLAY environment variable not set"**
- Make sure you're running in a graphical environment
- If using SSH, use `ssh -X` for X11 forwarding

**"Cannot connect to X11 display"**
- Verify X11 is running: `xdpyinfo`
- Check DISPLAY variable: `echo $DISPLAY`

**"fuse-sdl not found"**
- Install FUSE emulator: `sudo apt-get install fuse-emulator-sdl`

**"WebSocket connection failed"**
- Check if server is running on port 8765
- Look at server logs for error messages

**"Video stream not loading"**
- Wait a few seconds for FFmpeg to start generating segments
- Check if HLS files are being created in `stream/hls/`
- Try clicking "🔄 Reload Stream" button

### Debug Mode

For detailed logging, modify `local_server.py` and set:
```python
logging.basicConfig(level=logging.DEBUG)
```

### Log Files

Server logs are displayed in the terminal. Web interface logs are shown in the browser's developer console and the on-page log section.

## ✅ Validation Checklist

Before proceeding to containerization, ensure all these work:

- [ ] Server starts without errors
- [ ] Web interface loads at http://localhost:8000
- [ ] WebSocket connects successfully
- [ ] Health endpoint responds at http://localhost:8080/health
- [ ] FUSE emulator starts when requested
- [ ] HLS video stream generates and plays
- [ ] Virtual keyboard sends keys to emulator
- [ ] Physical keyboard input works
- [ ] ✅ **YouTube streaming works** (if configured) - **CONFIRMED WORKING**
- [ ] All validation tests pass

### 🎥 YouTube Streaming Validation
- [ ] RTMP connection to YouTube established
- [ ] Stream appears in YouTube Studio dashboard
- [ ] Video content visible in YouTube preview
- [ ] Stream status shows "Ready to stream"
- [ ] Manual "GO LIVE" activation works

## 🐳 Next Steps

Once all local tests pass:

1. **Create Dockerfile**: Use the working local configuration as a template
2. **Build Container**: Test the containerized version locally first
3. **Push to ECR**: Upload the tested container image
4. **Deploy to ECS**: Update the task definition with the new image
5. **Validate Production**: Ensure production deployment works as expected

## 📝 Notes

- This local environment uses your actual X11 display (`:0`) instead of virtual Xvfb
- Files are served from the local filesystem instead of S3
- All networking is localhost-based
- The server runs as a regular Python process, not in a container

This approach ensures that any issues are caught and fixed in the development environment rather than being discovered during production deployment.
