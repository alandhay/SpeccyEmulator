# ZX Spectrum Emulator

A complete web-based ZX Spectrum emulator with real-time video streaming, YouTube live broadcasting, mouse support, and authentic keyboard interface using the open-source OpenSE ROM.

## Status: FULLY INTERACTIVE EMULATOR with OpenSE ROM! 🎮

### ✅ **Latest Achievements (OpenSE ROM Implementation - August 2025):**

**🎮 OpenSE ROM Integration - FULLY OPERATIONAL:**
- ✅ **Open Source ROM**: Uses OpenSE ROM - legally distributable and copyright-free
- ✅ **No External Dependencies**: No need to copy ROM files from host system
- ✅ **Automatic Configuration**: FUSE starts with `--rom-48 /usr/share/spectrum-roms/opense.rom`
- ✅ **Legal Compliance**: 100% open-source components, no copyright issues
- ✅ **Consistent Behavior**: Same ROM used across all environments and deployments

**🧹 Project Cleanup - COMPLETED:**
- ✅ **Archived Legacy Files**: 100+ outdated files moved to `/archive/` directory
- ✅ **Clean Codebase**: Main directory reduced to 15 core files
- ✅ **Clear Structure**: Logical separation of current vs. historical code
- ✅ **Focused Development**: Only active, working files in main directory

**🐳 Docker Workflow - STREAMLINED:**
- ✅ **OpenSE ROM Scripts**: Complete build/test/deploy pipeline for OpenSE ROM
- ✅ **Updated Docker Scripts**: All scripts updated for OpenSE ROM configuration
- ✅ **Simplified Build Process**: Single command builds and tests OpenSE ROM version
- ✅ **Local Testing Confirmed**: Docker container working perfectly with OpenSE ROM

**🎥 Video Streaming Pipeline - PROVEN WORKING:**
- ✅ **Screen Capture**: Complete emulator display capture with no missing pixels
- ✅ **Dual Streaming**: Both HLS (web) and RTMP (YouTube) streams operational
- ✅ **Interactive Input**: Full keyboard and mouse support with real-time feedback
- ✅ **Production Ready**: Proven configuration ready for deployment

### 📊 **Current Clean Architecture:**

```
SpeccyEmulator/
├── 📄 Core Files
│   ├── README.md                                    # This documentation
│   ├── CLEANUP_SUMMARY.md                          # Project cleanup details
│   └── Dockerfile                                  # Basic Dockerfile
│
├── 🐳 OpenSE ROM Implementation
│   ├── fixed-emulator-opense-rom.dockerfile        # ✅ CURRENT: OpenSE ROM
│   ├── build-opense-rom.sh                         # ✅ Build OpenSE ROM version
│   ├── test-opense-rom.sh                          # ✅ Test OpenSE ROM functionality
│   └── deploy-opense-rom.sh                        # ✅ Complete deployment pipeline
│
├── 🔧 Docker Management
│   ├── docker-build.sh                             # ✅ Updated for OpenSE ROM
│   ├── docker-start.sh                             # ✅ Updated for OpenSE ROM
│   ├── docker-stop.sh                              # ✅ Enhanced container management
│   └── docker-status.sh                            # ✅ Comprehensive status reporting
│
├── 🖥️ Server Implementation
│   └── server/
│       ├── emulator_server_golden_reference_v2_final.py  # ✅ With OpenSE ROM config
│       ├── requirements.txt                        # Python dependencies
│       └── start.sh                                # Server startup script
│
├── 🌐 Web Interface
│   └── web/                                        # Frontend interface
│
├── ☁️ Infrastructure
│   ├── infrastructure/                             # AWS infrastructure code
│   └── aws/                                        # AWS deployment configurations
│
├── 📁 Supporting Directories
│   ├── games/                                      # Game files (.tzx, .tap, .z80)
│   ├── docs/                                       # Documentation
│   ├── tests/                                      # Test files
│   ├── logs/                                       # Application logs
│   └── local-test/                                 # Local testing environment
│
└── 📦 Archive
    └── archive/                                    # ✅ Archived legacy files
        ├── README.md                               # Archive documentation
        ├── dockerfiles/                            # 25 old Dockerfiles
        ├── task-definitions/                       # 40+ old task definitions
        ├── server-versions/                        # 22 old server versions
        ├── build-scripts/                          # 15 old build scripts
        ├── test-scripts/                           # 6 old test scripts
        ├── python-scripts/                         # 12 old Python utilities
        └── documentation/                          # 20 old documentation files
```

## Quick Start

### 🚀 **Local Development (Recommended)**

```bash
# Build the OpenSE ROM version
./build-opense-rom.sh

# Test the build
./test-opense-rom.sh

# Start container for development
./docker-start.sh

# Check status
./docker-status.sh

# Stop when done
./docker-stop.sh
```

### 🏭 **Production Deployment**

```bash
# Complete deployment pipeline
./deploy-opense-rom.sh
```

## OpenSE ROM Benefits

### ✅ **Legal & Compliance**
- **Open Source**: OpenSE ROM is completely open-source
- **No Copyright Issues**: Can be freely distributed and deployed
- **No External Dependencies**: ROM included in Docker image
- **Consistent Licensing**: All components are open-source

### ✅ **Technical Advantages**
- **Reliable Builds**: No ROM file copying required
- **Consistent Behavior**: Same ROM across all environments
- **Simplified Deployment**: Single Docker image contains everything
- **No Configuration Drift**: ROM always available and consistent

### ✅ **Compatibility**
- **ZX Spectrum 48K**: Full compatibility with 48K software
- **BASIC Programming**: Complete BASIC interpreter
- **Game Compatibility**: Works with most ZX Spectrum games
- **Authentic Experience**: Maintains ZX Spectrum behavior and timing

## Current Features

### 🎮 **Emulator Core**
- ✅ **FUSE Emulator**: Industry-standard ZX Spectrum emulation
- ✅ **OpenSE ROM**: Open-source ZX Spectrum 48K ROM
- ✅ **Full Keyboard**: Complete ZX Spectrum keyboard layout
- ✅ **Mouse Support**: Point-and-click interaction
- ✅ **Real-time Input**: Low-latency keyboard and mouse input

### 🎥 **Video Streaming**
- ✅ **HLS Streaming**: HTTP Live Streaming for web browsers
- ✅ **YouTube Live**: RTMP streaming to YouTube Live
- ✅ **Perfect Scaling**: Native 256x192 → 512x384 pixel-perfect rendering
- ✅ **No Cursor**: Clean video streams without mouse pointer
- ✅ **Low Latency**: ~2-3 second delay for interactive use

### 🌐 **Web Interface**
- ✅ **Responsive Design**: Works on desktop and mobile
- ✅ **Virtual Keyboard**: Click-only ZX Spectrum keyboard
- ✅ **Video Player**: HLS.js-based video streaming
- ✅ **Real-time Logs**: Live status and debugging information
- ✅ **Interactive Controls**: Start/stop emulator, send commands

### ☁️ **Infrastructure**
- ✅ **AWS ECS**: Containerized deployment on Fargate
- ✅ **CloudFront**: Global CDN for web content and streaming
- ✅ **S3 Storage**: HLS video segments and static content
- ✅ **Application Load Balancer**: WebSocket and HTTP routing
- ✅ **Auto Scaling**: Health checks and automatic recovery

## Usage

### 🌐 **Web Interface**
1. Open the web interface in your browser
2. Wait for video stream to load (shows ZX Spectrum boot sequence)
3. Use multiple input methods:
   - **Physical keyboard**: Type normally (mapped to Spectrum layout)
   - **Virtual keyboard**: Click the ZX Spectrum keys
   - **Mouse**: Click directly on the video to interact

### ⌨️ **Controls**
- **QAOP**: Up, Left, Down, Right movement (common in games)
- **Space**: Fire/Jump
- **Enter**: Start/Confirm
- **Numbers 1-0**: Various functions
- **All ZX Spectrum Keys**: Full keyboard support

### 🎮 **Programming**
```basic
PRINT "Hello, World!"
FOR I = 1 TO 10: PRINT I: NEXT I
LOAD ""
SAVE "program"
```

## Development

### 🔧 **Local Testing**
```bash
# Build and test locally
./build-opense-rom.sh
./test-opense-rom.sh

# Start development container
./docker-start.sh

# Test keyboard input
docker exec spectrum-emulator-opense-test bash -c 'export DISPLAY=:99 && WIN=$(xdotool search --name "Fuse" | head -1) && xdotool type --window $WIN "PRINT 2+2" && xdotool key --window $WIN Return'

# Check status
./docker-status.sh
```

### 🐳 **Docker Commands**
```bash
# Build OpenSE ROM image
docker build -f fixed-emulator-opense-rom.dockerfile -t spectrum-emulator:opense-rom .

# Run locally
docker run -p 8080:8080 -p 8765:8765 spectrum-emulator:opense-rom

# Health check
curl http://localhost:8080/health

# WebSocket test
echo '{"type":"status"}' | websocat ws://localhost:8765
```

### 📊 **Monitoring**
```bash
# Container logs
docker logs -f spectrum-emulator-opense-test

# ECS logs (production)
aws logs tail "/ecs/spectrum-emulator-streaming" --follow

# Health status
curl -s http://localhost:8080/health | jq .
```

## Architecture Details

### 🎯 **OpenSE ROM Implementation**
The emulator uses the OpenSE ROM, which is an open-source implementation of the ZX Spectrum 48K ROM:

```python
# FUSE startup command with OpenSE ROM
fuse_cmd = [
    'fuse-sdl',
    '--machine', '48',
    '--no-sound',
    '--rom-48', '/usr/share/spectrum-roms/opense.rom'
]
```

### 🔄 **Input Processing Pipeline**
```
User Input → WebSocket → Python Server → xdotool → FUSE Emulator → Video Output
```

### 📺 **Video Streaming Pipeline**
```
FUSE Display → FFmpeg Capture → HLS Segments → S3 Storage → Browser Playback
                            → RTMP Stream → YouTube Live
```

### 🌐 **Network Architecture**
```
Browser → CloudFront → ALB → ECS Fargate → Docker Container
                    → S3 → HLS Segments
```

## Troubleshooting

### 🔍 **Common Issues**

**Container won't start:**
```bash
# Check Docker daemon
docker info

# Check image exists
docker images | grep spectrum-emulator

# View build logs
./build-opense-rom.sh
```

**No video stream:**
```bash
# Check HLS stream
curl -s "https://your-stream-url/hls/stream.m3u8"

# Check FFmpeg process
docker exec container-name ps aux | grep ffmpeg
```

**Keyboard not working:**
```bash
# Check FUSE process
docker exec container-name ps aux | grep fuse

# Test xdotool
docker exec container-name bash -c 'export DISPLAY=:99 && xdotool search --name "Fuse"'
```

### 📋 **Debug Commands**
```bash
# Container status
./docker-status.sh

# Detailed logs
docker logs -f spectrum-emulator-opense-test

# Process list
docker exec spectrum-emulator-opense-test ps aux

# X11 windows
docker exec spectrum-emulator-opense-test bash -c 'export DISPLAY=:99 && xdotool search --onlyvisible --name ".*"'
```

## Deployment

### 🏗️ **AWS Infrastructure**
- **Region**: us-east-1
- **ECS Cluster**: spectrum-emulator-cluster-dev
- **Service**: spectrum-youtube-streaming
- **Load Balancer**: spectrum-emulator-alb-dev
- **CloudFront**: Global distribution

### 🚀 **Deployment Process**
```bash
# Complete deployment
./deploy-opense-rom.sh

# Manual ECR push
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 043309319786.dkr.ecr.us-east-1.amazonaws.com
docker push 043309319786.dkr.ecr.us-east-1.amazonaws.com/spectrum-emulator:opense-rom
```

### 📊 **Production URLs**
- **Web Interface**: `https://d112s3ps8xh739.cloudfront.net`
- **Health Check**: `https://d112s3ps8xh739.cloudfront.net/health`
- **WebSocket**: `wss://d112s3ps8xh739.cloudfront.net/ws`

## Project History

### 📦 **Archive Information**
Legacy files have been moved to the `/archive/` directory to maintain a clean codebase while preserving project history. See `archive/README.md` for details on archived files and recovery instructions.

### 🎯 **Evolution**
- **v1-v7**: Various experimental implementations and fixes
- **v8**: OpenSE ROM integration and project cleanup
- **Current**: Clean, production-ready OpenSE ROM implementation

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test with OpenSE ROM: `./test-opense-rom.sh`
4. Submit a pull request

## License

This project is open source. The FUSE emulator is GPL licensed. The OpenSE ROM is open-source and freely distributable.

## Acknowledgments

- **FUSE Emulator**: The core ZX Spectrum emulation engine
- **OpenSE ROM**: Open-source ZX Spectrum ROM implementation
- **FFmpeg**: Video streaming capabilities
- **HLS.js**: Browser video streaming
- **ZX Spectrum Community**: For keeping the platform alive

---

**The emulator is fully interactive and ready to use with OpenSE ROM! 🎮**

**Latest Achievement**: Complete OpenSE ROM implementation with clean project structure, providing a legal, reliable, and fully-featured ZX Spectrum emulator experience.

For support or questions, check the troubleshooting section or create an issue.
