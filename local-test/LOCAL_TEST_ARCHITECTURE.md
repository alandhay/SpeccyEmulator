# Local Testing Architecture for ZX Spectrum Emulator

## Overview
Create a complete local testing environment that mirrors the production ECS deployment, allowing us to validate all functionality before containerization and deployment.

## Architecture Components

### 1. Local Test Environment Structure
```
local-test/
├── LOCAL_TEST_ARCHITECTURE.md     # This document
├── server/                        # Local server files
│   ├── local_server.py           # Local version of emulator server
│   ├── requirements.txt          # Python dependencies
│   └── start_local.sh            # Local startup script
├── web/                          # Local web interface
│   ├── index.html               # Test web interface
│   ├── css/
│   │   └── spectrum.css         # Styling
│   └── js/
│       └── spectrum-local.js    # Local client JavaScript
├── stream/                       # Local streaming output
│   └── hls/                     # HLS segments for local testing
├── logs/                        # Local log files
└── test-scripts/                # Testing utilities
    ├── test_websocket.py        # WebSocket connection tests
    ├── test_youtube.py          # YouTube streaming tests
    └── validate_all.py          # Complete validation suite
```

### 2. Local Server Configuration
- **Port 8080**: Health check and API endpoints
- **Port 8765**: WebSocket server for real-time communication
- **Port 8000**: Local HTTP server for web interface
- **Display**: Use local X11 display (not virtual Xvfb)
- **Audio**: Use local PulseAudio
- **Streaming**: Local HLS generation + optional YouTube RTMP

### 3. Testing Workflow
1. **Unit Tests**: Test individual components (WebSocket, streaming, emulator)
2. **Integration Tests**: Test complete workflow locally
3. **Validation**: Verify all features work as expected
4. **Containerization**: Only after local tests pass
5. **ECS Deployment**: Deploy tested and validated container

### 4. Key Differences from Production
| Component | Production (ECS) | Local Test |
|-----------|------------------|------------|
| Display | Xvfb :99 (virtual) | :0 (local X11) |
| Web Server | CloudFront + ALB | Python HTTP server |
| File Storage | S3 bucket | Local filesystem |
| Networking | AWS VPC | localhost |
| Process Management | ECS Fargate | Direct Python execution |

### 5. Testing Scenarios
- **WebSocket Connectivity**: Verify connection and message handling
- **Video Streaming**: Confirm HLS generation and playback
- **YouTube Streaming**: Test RTMP stream to YouTube Live
- **Emulator Integration**: Validate FUSE emulator control
- **Input Handling**: Test keyboard and mouse input
- **Error Handling**: Verify graceful error recovery

### 6. Validation Criteria
Before proceeding to containerization, all tests must pass:
- [ ] WebSocket server starts and accepts connections
- [ ] HLS video stream generates and plays in browser
- [ ] YouTube RTMP stream is active (if configured)
- [ ] FUSE emulator responds to input commands
- [ ] Virtual keyboard sends correct key codes
- [ ] Mouse clicks map to correct coordinates
- [ ] Health check endpoint responds correctly
- [ ] Error conditions are handled gracefully

### 7. Benefits of Local Testing
- **Faster Iteration**: No container build/push/deploy cycle
- **Better Debugging**: Direct access to logs and processes
- **Resource Efficiency**: No ECS costs during development
- **Isolated Testing**: No impact on production environment
- **Complete Validation**: Test all components before deployment

### 8. Implementation Steps
1. Create local server with same functionality as production
2. Set up local web interface for testing
3. Implement local streaming pipeline
4. Create comprehensive test suite
5. Validate all functionality locally
6. Only then proceed to Docker containerization

This approach ensures we catch and fix issues in the development environment rather than discovering them in production ECS deployments.
