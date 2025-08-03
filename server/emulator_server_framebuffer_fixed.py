#!/usr/bin/env python3
"""
ZX Spectrum Emulator Server - Framebuffer Capture Fixed Version
================================================================

This is the PRODUCTION-READY version of the ZX Spectrum emulator server that
resolves two critical issues that were preventing proper operation:

CRITICAL FIXES IMPLEMENTED:
===========================

1. SCREEN CUT-OFF FIX:
   - Problem: FUSE emulator creates 320x240 window but FFmpeg captured 256x192
   - Result: Missing 64 pixels right, 48 pixels bottom
   - Solution: Updated capture dimensions to match actual window geometry
   - Files: capture_size changed from "256x192" to "320x240"

2. WEBSOCKET HANDLER FIX:
   - Problem: TypeError - missing 'path' parameter in handle_websocket function
   - Result: WebSocket connections failing with TypeError
   - Solution: Corrected function signature for websockets library compatibility
   - Files: handle_websocket(self, websocket) instead of (self, websocket, path)

TECHNICAL SPECIFICATIONS:
========================

Video Pipeline:
- FUSE Emulator: 320x240 native window
- Xvfb Display: :99 at 320x240x24
- FFmpeg Capture: 320x240 input
- FFmpeg Output: 640x480 (2x scaled with neighbor interpolation)
- Frontend Display: Up to 960px width (responsive)

Streaming Outputs:
- HLS Stream: 2-second segments, 5-segment playlist
- RTMP Stream: YouTube Live compatible
- Both streams: 25 FPS, H.264/AAC encoding

Container Configuration:
- Docker Image: spectrum-emulator:framebuffer-capture-fixed
- ECS Task Definition: spectrum-emulator-streaming:47
- Version: 1.0.0-framebuffer-capture-fixed
- Health Check Grace: 120 seconds

DEPLOYMENT INFORMATION:
======================

This version is deployed as:
- ECS Service: spectrum-youtube-streaming
- Task Definition: spectrum-emulator-streaming:47
- Status: PRODUCTION READY ✅

DO NOT MODIFY the following critical parameters without testing:
- capture_size = "320x240"
- display_size = "320x240" 
- output_size = "640x480"
- WebSocket handler signature: handle_websocket(self, websocket)

For detailed documentation, see:
- /documentation/VIDEO_STREAMING_AND_LAYOUT_FIXES.md
- README.md (Status: v8 section)

Author: ZX Spectrum Emulator Team
Date: August 2025
Version: 1.0.0-framebuffer-capture-fixed
"""

import asyncio
import websockets
import json
import subprocess
import threading
import time
import os
import signal
import sys
import logging
from aiohttp import web
import boto3
from botocore.exceptions import ClientError

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class FramebufferEmulatorServer:
    def __init__(self):
        self.websocket_clients = set()
        self.emulator_process = None
        self.xvfb_process = None
        self.pulseaudio_process = None
        self.ffmpeg_hls_process = None
        self.ffmpeg_youtube_process = None
        self.s3_client = None
        self.upload_thread = None
        self.running = True
        
        # Environment configuration
        self.stream_bucket = os.getenv('STREAM_BUCKET', 'spectrum-emulator-stream-dev-043309319786')
        self.youtube_key = os.getenv('YOUTUBE_STREAM_KEY', '')
        self.version = os.getenv('VERSION', '1.0.0-framebuffer-capture-fixed')
        self.build_time = os.getenv('BUILD_TIME', '2025-08-03T08:30:00Z')
        
        # FIXED: Framebuffer configuration to match actual FUSE window size
        self.display_size = "320x240"  # Match actual FUSE window size
        self.capture_size = "320x240"  # Capture the full window
        self.output_size = "640x480"   # 2x scaling for web display
        
        logger.info("Starting Framebuffer ZX Spectrum Emulator Server")
        logger.info(f"Version: {self.version}")
        logger.info(f"Build Time: {self.build_time}")
        logger.info(f"Display Size: {self.display_size}")
        logger.info(f"Capture Size: {self.capture_size}")
        logger.info(f"Output Size: {self.output_size}")

    def setup_s3_client(self):
        """Initialize S3 client for HLS uploads"""
        try:
            self.s3_client = boto3.client('s3')
            logger.info("S3 client initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize S3 client: {e}")
            raise

    def start_xvfb(self):
        """Start virtual framebuffer with exact dimensions"""
        try:
            logger.info("Starting Xvfb virtual framebuffer...")
            logger.info(f"Creating framebuffer with resolution: {self.display_size}x24")
            
            self.xvfb_process = subprocess.Popen([
                'Xvfb', ':99', 
                '-screen', '0', f'{self.display_size}x24',
                '-ac', '+extension', 'GLX'
            ])
            
            # Wait for Xvfb to start
            time.sleep(3)
            
            # Verify display is available
            result = subprocess.run(['xdpyinfo', '-display', ':99'], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                logger.info("Xvfb started successfully on display :99")
                logger.info(f"Display info: {self.display_size} pixels")
            else:
                raise Exception("Xvfb failed to start properly")
                
        except Exception as e:
            logger.error(f"Failed to start Xvfb: {e}")
            raise

    def start_pulseaudio(self):
        """Start PulseAudio for audio support"""
        try:
            logger.info("Starting PulseAudio...")
            self.pulseaudio_process = subprocess.Popen([
                'pulseaudio', '--start', '--exit-idle-time=-1'
            ], env=dict(os.environ, DISPLAY=':99'))
            
            time.sleep(2)
            logger.info("PulseAudio started successfully")
        except Exception as e:
            logger.error(f"Failed to start PulseAudio: {e}")
            raise

    def start_ffmpeg_hls(self):
        """Start FFmpeg HLS streaming with FIXED capture size"""
        try:
            logger.info("Starting FFmpeg HLS with framebuffer capture...")
            logger.info(f"Capture: {self.capture_size}, Output: {self.output_size}")
            
            # FIXED: FFmpeg command with correct capture size
            ffmpeg_cmd = [
                'ffmpeg',
                # Input: X11 grab with FIXED dimensions (320x240)
                '-f', 'x11grab',
                '-video_size', self.capture_size,  # Now captures full 320x240 window
                '-framerate', '25',
                '-draw_mouse', '0',  # Hide cursor
                '-i', ':99.0+0,0',
                
                # Audio input
                '-f', 'pulse',
                '-i', 'default',
                
                # Video processing: Scale to output size with pixel-perfect scaling
                '-vf', f'scale={self.output_size}:flags=neighbor',
                
                # Video encoding
                '-c:v', 'libx264',
                '-preset', 'ultrafast',
                '-tune', 'zerolatency',
                '-pix_fmt', 'yuv420p',
                
                # Audio encoding
                '-c:a', 'aac',
                '-b:a', '128k',
                
                # HLS output
                '-f', 'hls',
                '-hls_time', '2',
                '-hls_list_size', '5',
                '-hls_flags', 'delete_segments',
                '-hls_segment_filename', '/tmp/stream/stream%d.ts',
                '/tmp/stream/stream.m3u8'
            ]
            
            logger.info(f"FFmpeg HLS command: {' '.join(ffmpeg_cmd)}")
            
            # Create output directory
            os.makedirs('/tmp/stream', exist_ok=True)
            
            self.ffmpeg_hls_process = subprocess.Popen(
                ffmpeg_cmd,
                env=dict(os.environ, DISPLAY=':99')
            )
            
            time.sleep(3)
            logger.info("✅ FFmpeg HLS started successfully with framebuffer capture")
            
        except Exception as e:
            logger.error(f"Failed to start FFmpeg HLS: {e}")
            raise

    def start_ffmpeg_youtube(self):
        """Start FFmpeg YouTube RTMP streaming with FIXED capture size"""
        if not self.youtube_key:
            logger.info("No YouTube stream key provided, skipping RTMP stream")
            return
            
        try:
            logger.info("Starting YouTube RTMP stream with framebuffer capture...")
            
            # FIXED: YouTube FFmpeg command with correct capture size
            youtube_cmd = [
                'ffmpeg', '-y',
                # Input: Same framebuffer capture with FIXED size
                '-f', 'x11grab',
                '-video_size', self.capture_size,  # Now captures full 320x240 window
                '-framerate', '25',
                '-draw_mouse', '0',
                '-i', ':99.0+0,0',
                
                # Audio input
                '-f', 'pulse',
                '-i', 'default',
                
                # Video processing: Scale for YouTube
                '-vf', f'scale={self.output_size}:flags=neighbor',
                
                # Video encoding for streaming
                '-c:v', 'libx264',
                '-preset', 'veryfast',
                '-tune', 'zerolatency',
                '-g', '50',
                '-keyint_min', '25',
                '-sc_threshold', '0',
                '-b:v', '2500k',
                '-maxrate', '3000k',
                '-bufsize', '6000k',
                '-pix_fmt', 'yuv420p',
                
                # Audio encoding
                '-c:a', 'aac',
                '-b:a', '128k',
                '-ar', '44100',
                
                # RTMP output
                '-f', 'flv',
                f'rtmp://a.rtmp.youtube.com/live2/{self.youtube_key}'
            ]
            
            logger.info(f"YouTube FFmpeg command: {' '.join(youtube_cmd)}")
            
            self.ffmpeg_youtube_process = subprocess.Popen(
                youtube_cmd,
                env=dict(os.environ, DISPLAY=':99')
            )
            
            time.sleep(3)
            logger.info("✅ YouTube RTMP streaming started successfully")
            
        except Exception as e:
            logger.error(f"Failed to start YouTube streaming: {e}")
            raise

    def start_emulator(self):
        """Start FUSE emulator in framebuffer mode"""
        try:
            logger.info("Starting FUSE emulator in framebuffer mode...")
            
            # FUSE command for framebuffer mode
            fuse_cmd = [
                'fuse-sdl',
                '--machine', '48',
                '--graphics-filter', 'none',
                '--fullscreen',
                '--no-sound'
            ]
            
            logger.info(f"FUSE command: {' '.join(fuse_cmd)}")
            
            self.emulator_process = subprocess.Popen(
                fuse_cmd,
                env=dict(os.environ, DISPLAY=':99', SDL_VIDEODRIVER='x11')
            )
            
            # Wait for emulator to start and create window
            time.sleep(5)
            
            # Verify emulator started
            if self.emulator_process.poll() is None:
                logger.info("✅ FUSE emulator started successfully in framebuffer mode")
                
                # Validate framebuffer dimensions
                try:
                    result = subprocess.run(['xdpyinfo', '-display', ':99'], 
                                          capture_output=True, text=True)
                    if self.display_size in result.stdout:
                        logger.info(f"✅ Framebuffer validated: {self.display_size} dimensions")
                    
                    # Find FUSE window
                    result = subprocess.run(['xwininfo', '-root', '-tree'], 
                                          env={'DISPLAY': ':99'}, 
                                          capture_output=True, text=True)
                    if 'fuse' in result.stdout.lower():
                        logger.info("✅ FUSE window found")
                        # Log window geometry for debugging
                        window_lines = [line for line in result.stdout.split('\n') 
                                      if 'fuse' in line.lower() or '0x' in line]
                        for line in window_lines[-3:]:  # Last few lines with window info
                            logger.info(f"Window geometry: {line.strip()}")
                    
                except Exception as e:
                    logger.warning(f"Could not validate window: {e}")
                    
            else:
                raise Exception("FUSE emulator failed to start")
                
        except Exception as e:
            logger.error(f"Failed to start FUSE emulator: {e}")
            raise

    def upload_hls_segments(self):
        """Upload HLS segments to S3"""
        while self.running:
            try:
                # Look for .ts files in /tmp/stream/
                for filename in os.listdir('/tmp/stream'):
                    if filename.endswith('.ts') or filename.endswith('.m3u8'):
                        local_path = f'/tmp/stream/{filename}'
                        s3_key = f'hls/{filename}'
                        
                        try:
                            with open(local_path, 'rb') as f:
                                self.s3_client.upload_fileobj(
                                    f, self.stream_bucket, s3_key,
                                    ExtraArgs={'ContentType': 'video/mp2t' if filename.endswith('.ts') else 'application/x-mpegURL'}
                                )
                        except FileNotFoundError:
                            # File was deleted by FFmpeg, skip
                            continue
                        except Exception as e:
                            logger.error(f"S3 upload error: {e}")
                            
                time.sleep(1)
            except Exception as e:
                logger.error(f"Upload thread error: {e}")
                time.sleep(5)

    def start_s3_upload_thread(self):
        """Start S3 upload thread"""
        self.upload_thread = threading.Thread(target=self.upload_hls_segments, daemon=True)
        self.upload_thread.start()
        logger.info("S3 upload thread started")

    # FIXED: WebSocket handler with proper signature
    async def handle_websocket(self, websocket):
        """Handle WebSocket connections - FIXED signature"""
        logger.info("WebSocket connection established")
        self.websocket_clients.add(websocket)
        
        try:
            # Send initial status
            await websocket.send(json.dumps({
                'type': 'connected',
                'emulator_running': self.emulator_process is not None and self.emulator_process.poll() is None,
                'version': self.version,
                'framebuffer_mode': True
            }))
            
            async for message in websocket:
                try:
                    data = json.loads(message)
                    await self.handle_message(websocket, data)
                except json.JSONDecodeError:
                    logger.error(f"Invalid JSON received: {message}")
                except Exception as e:
                    logger.error(f"Error handling message: {e}")
                    
        except websockets.exceptions.ConnectionClosed:
            logger.info("WebSocket connection closed")
        except Exception as e:
            logger.error(f"WebSocket error: {e}")
        finally:
            self.websocket_clients.discard(websocket)

    async def handle_message(self, websocket, data):
        """Handle incoming WebSocket messages"""
        message_type = data.get('type')
        
        if message_type == 'status':
            # Send status update
            await websocket.send(json.dumps({
                'type': 'status_response',
                'emulator_running': self.emulator_process is not None and self.emulator_process.poll() is None,
                'services': {
                    'xvfb': self.xvfb_process is not None and self.xvfb_process.poll() is None,
                    'emulator': self.emulator_process is not None and self.emulator_process.poll() is None,
                    'ffmpeg_hls': self.ffmpeg_hls_process is not None and self.ffmpeg_hls_process.poll() is None,
                    'ffmpeg_youtube': self.ffmpeg_youtube_process is not None and self.ffmpeg_youtube_process.poll() is None
                },
                'version': self.version,
                'framebuffer_mode': True
            }))
            
        elif message_type == 'key_press':
            # Handle key press (placeholder for future implementation)
            key = data.get('key', '')
            logger.info(f"Key press received: {key}")
            
            # Send acknowledgment
            await websocket.send(json.dumps({
                'type': 'key_response',
                'key': key,
                'status': 'received'
            }))

    async def health_handler(self, request):
        """Health check endpoint"""
        status = {
            'status': 'healthy',
            'version': self.version,
            'framebuffer_mode': True,
            'services': {
                'xvfb': self.xvfb_process is not None and self.xvfb_process.poll() is None,
                'emulator': self.emulator_process is not None and self.emulator_process.poll() is None,
                'ffmpeg_hls': self.ffmpeg_hls_process is not None and self.ffmpeg_hls_process.poll() is None,
                'ffmpeg_youtube': self.ffmpeg_youtube_process is not None and self.ffmpeg_youtube_process.poll() is None
            }
        }
        return web.json_response(status)

    def cleanup(self):
        """Clean up processes"""
        logger.info("Cleaning up processes...")
        self.running = False
        
        processes = [
            ('FFmpeg YouTube', self.ffmpeg_youtube_process),
            ('FFmpeg HLS', self.ffmpeg_hls_process),
            ('FUSE Emulator', self.emulator_process),
            ('PulseAudio', self.pulseaudio_process),
            ('Xvfb', self.xvfb_process)
        ]
        
        for name, process in processes:
            if process:
                try:
                    process.terminate()
                    process.wait(timeout=5)
                    logger.info(f"{name} terminated")
                except subprocess.TimeoutExpired:
                    process.kill()
                    logger.info(f"{name} killed")
                except Exception as e:
                    logger.error(f"Error stopping {name}: {e}")

    async def run(self):
        """Main server run method"""
        try:
            # Initialize S3 client
            self.setup_s3_client()
            
            # Start virtual display
            self.start_xvfb()
            
            # Start audio system
            self.start_pulseaudio()
            
            # Start video streaming
            self.start_ffmpeg_hls()
            self.start_ffmpeg_youtube()
            
            # Start S3 upload thread
            self.start_s3_upload_thread()
            
            # Start emulator
            self.start_emulator()
            
            # Start health check server
            app = web.Application()
            app.router.add_get('/health', self.health_handler)
            runner = web.AppRunner(app)
            await runner.setup()
            site = web.TCPSite(runner, '0.0.0.0', 8080)
            await site.start()
            logger.info("Health check server started on port 8080")
            
            # Start WebSocket server with FIXED handler
            start_server = websockets.serve(
                self.handle_websocket, '0.0.0.0', 8765
            )
            websocket_server = await start_server
            logger.info("WebSocket server started on port 8765")
            
            logger.info("🎮 All services started! Framebuffer ZX Spectrum Emulator ready!")
            logger.info(f"📺 FIXED Framebuffer Mode: {self.display_size} → {self.output_size}")
            
            # Keep server running indefinitely
            await websocket_server.wait_closed()
            
        except Exception as e:
            logger.error(f"Failed to start server: {e}")
            self.cleanup()
            raise

def signal_handler(signum, frame):
    """Handle shutdown signals"""
    logger.info("Received shutdown signal")
    sys.exit(0)

if __name__ == "__main__":
    # Set up signal handlers
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)
    
    # Create and run server
    server = FramebufferEmulatorServer()
    
    try:
        asyncio.run(server.run())
    except KeyboardInterrupt:
        logger.info("Server stopped by user")
    except Exception as e:
        logger.error(f"Server error: {e}")
    finally:
        server.cleanup()
