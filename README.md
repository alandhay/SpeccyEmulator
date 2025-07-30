# ZX Spectrum Emulator

A complete web-based ZX Spectrum emulator with real-time video streaming and authentic keyboard interface.

## Status: COMPLETE ✅

This project is fully functional with:
- ✅ Web interface with authentic ZX Spectrum keyboard
- ✅ Python WebSocket server
- ✅ Real-time video streaming via FFmpeg
- ✅ FUSE emulator integration
- ✅ Complete automation scripts
- ✅ Game loading support
- ✅ Screenshot capture
- ✅ Fullscreen mode
- ✅ Multi-user support

## Quick Start

### 1. Setup (First Time Only)
```bash
./scripts/setup.sh
```

### 2. Start the Emulator
```bash
./scripts/start-emulator.sh
```

### 3. Access the Web Interface
Open http://localhost:8080 in your browser.

### 4. Stop the Emulator
```bash
./scripts/stop-emulator.sh
```
Or press `Ctrl+C` in the terminal running the emulator.

## Project Structure

```
SpeccyEmulator/
├── web/                    # Frontend web interface
│   ├── index.html         # Main HTML interface
│   ├── css/
│   │   └── spectrum.css   # ZX Spectrum themed styling
│   └── js/
│       ├── spectrum-emulator.js  # Main client JavaScript
│       └── hls.min.js     # Video streaming library
├── server/                # Python backend
│   ├── emulator_server.py # WebSocket server
│   └── requirements.txt   # Python dependencies
├── scripts/               # Automation scripts
│   ├── setup.sh          # Initial setup script
│   ├── start-emulator.sh # Main startup script
│   └── stop-emulator.sh  # Shutdown script
├── games/                 # Game files (.tzx, .tap, .z80, .sna)
├── stream/               # Video streaming output
│   └── hls/             # HLS streaming files
├── logs/                 # Application logs
└── venv/                # Python virtual environment
```

## Features

### 🎮 Emulation
- Full ZX Spectrum 48K emulation via FUSE
- Support for .tzx, .tap, .z80, and .sna formats
- Authentic timing and behavior
- Save/load state functionality

### 🖥️ Web Interface
- Responsive design works on desktop and mobile
- Authentic ZX Spectrum keyboard layout
- Real-time video streaming
- Game loading interface
- Screenshot capture
- Fullscreen mode

### 🔧 Technical Features
- WebSocket communication for real-time control
- HLS video streaming for low latency
- Multi-user support (multiple browsers can connect)
- Automatic cleanup and process management
- Cross-platform compatibility (Linux/macOS/Windows with WSL)

## Requirements

### System Requirements
- Linux (Ubuntu/Debian recommended)
- Python 3.8+
- X11 display server
- 1GB RAM minimum
- Modern web browser with WebSocket support

### Dependencies (Installed by setup.sh)
- FUSE emulator
- FFmpeg
- Python packages (websockets, aiohttp, etc.)
- ImageMagick (for screenshots)

## Usage

### Starting the Emulator
1. Run `./scripts/start-emulator.sh`
2. Open http://localhost:8080 in your browser
3. Click "Start Emulator"
4. The emulator will appear in the video window

### Loading Games
1. Place game files in the `games/` directory
2. Select a game from the dropdown menu
3. Click "Load Game"
4. The game will start automatically

### Controls
- **On-screen keyboard**: Click the ZX Spectrum keys
- **Physical keyboard**: Type normally (mapped to Spectrum layout)
- **Special keys**:
  - F11: Toggle fullscreen
  - F2: Save state (when implemented)
  - F3: Load state (when implemented)

### Game Controls
Most games use these controls:
- **QAOP**: Up, Left, Down, Right movement
- **Space**: Fire/Jump
- **Enter**: Start/Confirm
- **Numbers 1-0**: Various functions

## Configuration

### Server Ports
- **Web Interface**: http://localhost:8080
- **WebSocket Server**: ws://localhost:8765
- **Video Stream**: http://localhost:8080/stream/hls/stream.m3u8

### Customization
- Edit `server/emulator_server.py` for server behavior
- Modify `web/css/spectrum.css` for styling
- Update `web/js/spectrum-emulator.js` for client features

## AWS CloudFront Deployment

### Prerequisites
- AWS CLI installed and configured
- Docker installed
- jq installed (for JSON parsing)

### Quick AWS Deployment
```bash
# Deploy everything to AWS
./scripts/deploy-complete.sh

# Test the deployment
./scripts/test-deployment.sh
```

### Custom Domain Deployment
```bash
# Deploy with custom domain and SSL certificate
./scripts/deploy-complete.sh \
  --domain your-domain.com \
  --certificate-arn arn:aws:acm:us-east-1:123456789012:certificate/your-cert-id
```

### Manual Step-by-Step Deployment

1. **Deploy Infrastructure**:
   ```bash
   ./scripts/deploy-aws.sh --environment prod --region us-east-1
   ```

2. **Build and Deploy Backend**:
   ```bash
   # Build Docker image
   docker build -t spectrum-emulator .
   
   # Deploy to ECS (requires ECR setup)
   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com
   docker tag spectrum-emulator:latest 123456789012.dkr.ecr.us-east-1.amazonaws.com/spectrum-emulator:latest
   docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/spectrum-emulator:latest
   ```

### Architecture

The AWS deployment includes:

- **CloudFront Distribution**: Global CDN for web content and API routing
- **S3 Buckets**: Static web content and HLS video streaming
- **Application Load Balancer**: Routes WebSocket and API traffic
- **ECS Fargate**: Containerized emulator backend
- **ECR**: Docker image repository

### URLs and Endpoints

After deployment, your emulator will be available at:
- **Web Interface**: `https://your-cloudfront-domain.cloudfront.net`
- **WebSocket**: `wss://your-cloudfront-domain.cloudfront.net/ws`
- **Video Stream**: `https://your-cloudfront-domain.cloudfront.net/stream/hls/stream.m3u8`

### Monitoring and Logs

- **ECS Logs**: CloudWatch Logs group `/ecs/spectrum-emulator-{environment}`
- **CloudFront Metrics**: CloudWatch CloudFront metrics
- **ALB Metrics**: CloudWatch Application Load Balancer metrics

### Cost Optimization

- Uses Fargate Spot for cost savings
- CloudFront caching reduces origin requests
- S3 lifecycle policies for old stream segments
- Auto-scaling based on CPU utilization

### Cleanup

To remove all AWS resources:
```bash
# Delete ECS stack
aws cloudformation delete-stack --stack-name spectrum-emulator-ecs

# Delete infrastructure stack
aws cloudformation delete-stack --stack-name spectrum-emulator-infrastructure

# Delete ECR repository
aws ecr delete-repository --repository-name spectrum-emulator --force
```

### Common Issues

**"FUSE emulator not found"**
```bash
sudo apt-get install fuse-emulator-sdl
```

**"X11 server not running"**
```bash
# For desktop systems:
startx

# For headless systems:
./scripts/start-x11.sh  # (created by setup.sh)
```

**"Video streaming not working"**
- Check if FFmpeg is installed: `ffmpeg -version`
- Ensure X11 is running: `echo $DISPLAY`
- Try refreshing the browser page

**"WebSocket connection failed"**
- Check if port 8765 is available: `lsof -i :8765`
- Restart the emulator: `./scripts/stop-emulator.sh && ./scripts/start-emulator.sh`

### Logs
Check logs in the `logs/` directory:
- Application logs from the Python server
- Process IDs for cleanup

## Development

### Adding Features
1. Server-side: Edit `server/emulator_server.py`
2. Client-side: Edit `web/js/spectrum-emulator.js`
3. Styling: Edit `web/css/spectrum.css`

### Testing
- Use browser developer tools for debugging
- Check WebSocket messages in the Network tab
- Monitor server logs for backend issues

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is open source. The FUSE emulator is GPL licensed.

## Acknowledgments

- **FUSE Emulator**: The core ZX Spectrum emulation
- **FFmpeg**: Video streaming capabilities
- **HLS.js**: Browser video streaming
- **ZX Spectrum Community**: For keeping the platform alive

---

**The emulator is ready to use! 🎮**

For support or questions, check the troubleshooting section or create an issue.
