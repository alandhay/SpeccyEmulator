# ZX Spectrum Emulator

A complete web-based ZX Spectrum emulator with real-time video streaming and authentic keyboard interface.

## Status: COMPLETE ✅

This project is fully functional with:
- Web interface with authentic ZX Spectrum keyboard
- Python WebSocket server
- Real-time video streaming via FFmpeg
- FUSE emulator integration
- Complete automation scripts

## Quick Start

```bash
./scripts/start-emulator.sh
```

Then open http://localhost:8080 in your browser.

## Project Structure

- `web/` - HTML, CSS, JavaScript frontend
- `server/` - Python backend with WebSocket server
- `scripts/` - Automation and setup scripts
- `games/` - Game files (.tzx, .tap)
- `stream/` - Video streaming output

## Features

- Real-time video streaming (HLS)
- Authentic ZX Spectrum keyboard interface
- WebSocket communication
- Game loading support
- Screenshot capture
- Fullscreen mode
- Multi-user support

The emulator is ready to use!
