#!/usr/bin/env python3

import asyncio
import websockets
import json
import logging
import subprocess
import threading
import time
import os
import signal
import boto3
from aiohttp import web
from pathlib import Path
from aiohttp.web import FileResponse

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SpectrumEmulatorUltraHD:
    def __init__(self):
        self.connected_clients = set()
        self.emulator_process = None
        self.web_stream_process = None
        self.youtube_stream_process = None
        self.s3_upload_process = None
        self.stream_dir = Path('/tmp/stream')
        self.stream_dir.mkdir(exist_ok=True)
        
        # Ultra HD Configuration
        self.capture_size = os.getenv('CAPTURE_SIZE', '256x192')  # ZX Spectrum native
        self.display_size = os.getenv('DISPLAY_SIZE', '1920x1080')  # Ultra HD display
        self.stream_resolution = os.getenv('STREAM_RESOLUTION', '1920x1080')  # Ultra HD output
        self.stream_bitrate = os.getenv('STREAM_BITRATE', '8000k')  # High bitrate for Ultra HD
        self.scaling_algorithm = os.getenv('SCALING_ALGORITHM', 'lanczos')  # High-quality scaling
        
        self.capture_offset = os.getenv('CAPTURE_OFFSET', '0,0')
        self.stream_bucket = os.getenv('STREAM_BUCKET', 'spectrum-emulator-stream-dev-043309319786')
        self.youtube_key = os.getenv('YOUTUBE_STREAM_KEY', '')
        
        # Initialize S3 client
        try:
            self.s3_client = boto3.client('s3')
            logger.info(f'S3 client initialized for bucket: {self.stream_bucket}')
        except Exception as e:
            logger.error(f'Failed to initialize S3 client: {e}')
            self.s3_client = None
        
        logger.info(f'Ultra HD Emulator config: display={self.display_size}, stream={self.stream_resolution}, bitrate={self.stream_bitrate}')

    async def handle_websocket(self, websocket, path):
        """Handle WebSocket connections from clients"""
        self.connected_clients.add(websocket)
        logger.info("New WebSocket client connected")
        
        try:
            # Send initial status
            await websocket.send(json.dumps({
                'type': 'connected',
                'emulator_running': self.emulator_process is not None,
                'resolution': self.stream_resolution,
                'bitrate': self.stream_bitrate
            }))
            
            async for message in websocket:
                try:
                    data = json.loads(message)
                    logger.info(f"Received message: {data}")
                    await self.handle_message(websocket, data)
                except json.JSONDecodeError:
                    logger.error(f"Invalid JSON received: {message}")
                except Exception as e:
                    logger.error(f"Error handling message: {e}")
                    
        except websockets.exceptions.ConnectionClosed:
            logger.info("WebSocket client disconnected")
        finally:
            self.connected_clients.discard(websocket)

    async def handle_message(self, websocket, data):
        """Handle incoming WebSocket messages"""
        message_type = data.get('type')
        
        if message_type == 'start_emulator':
            success = await self.start_emulator()
            await websocket.send(json.dumps({
                'type': 'emulator_status',
                'running': success,
                'message': 'Ultra HD Emulator started successfully' if success else 'Failed to start emulator',
                'resolution': self.stream_resolution
            }))
            
        elif message_type == 'stop_emulator':
            await self.stop_emulator()
            await websocket.send(json.dumps({
                'type': 'emulator_status',
                'running': False,
                'message': 'Emulator stopped'
            }))
            
        elif message_type == 'key_press':
            key = data.get('key')
            if key and self.emulator_process:
                await self.send_key_to_emulator(key)
                
        elif message_type == 'status':
            await websocket.send(json.dumps({
                'type': 'status_response',
                'emulator_running': self.emulator_process is not None,
                'resolution': self.stream_resolution,
                'bitrate': self.stream_bitrate,
                'scaling': self.scaling_algorithm
            }))

    async def start_emulator(self):
        """Start the ZX Spectrum emulator with Ultra HD configuration"""
        if self.emulator_process:
            logger.info("Emulator already running")
            return True
            
        try:
            logger.info("Testing SDL2 environment...")
            logger.info(f"Environment: DISPLAY={os.getenv('DISPLAY')}, SDL_VIDEODRIVER={os.getenv('SDL_VIDEODRIVER')}, SDL_AUDIODRIVER={os.getenv('SDL_AUDIODRIVER')}")
            
            # Test X11 display
            result = subprocess.run(['xdpyinfo', '-display', ':99'], 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                logger.info("X11 display test: SUCCESS")
            else:
                logger.error(f"X11 display test failed: {result.stderr}")
                return False
            
            # Check for FUSE emulator
            fuse_path = subprocess.run(['which', 'fuse-sdl'], capture_output=True, text=True)
            if fuse_path.returncode == 0:
                logger.info(f"FUSE emulator found at: {fuse_path.stdout.strip()}")
            else:
                logger.error("FUSE emulator not found")
                return False
            
            # Start FUSE emulator with Ultra HD display configuration
            logger.info("Starting FUSE ZX Spectrum emulator with Ultra HD configuration")
            
            # Configure virtual display for Ultra HD
            display_cmd = [
                'Xvfb', ':99', 
                '-screen', '0', f'{self.display_size}x24',
                '-ac', '+extension', 'GLX'
            ]
            
            # Kill existing Xvfb and restart with Ultra HD resolution
            subprocess.run(['pkill', '-f', 'Xvfb'], capture_output=True)
            time.sleep(2)
            
            xvfb_process = subprocess.Popen(display_cmd)
            time.sleep(3)  # Wait for display to initialize
            
            # Start FUSE with improved configuration
            fuse_cmd = [
                'fuse-sdl',
                '--display-scale', '8',  # Scale up for Ultra HD
                '--full-screen',
                '--no-sound',  # Disable sound to avoid conflicts
                '--speed', '100'
            ]
            
            self.emulator_process = subprocess.Popen(
                fuse_cmd,
                env={**os.environ, 'DISPLAY': ':99'},
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            
            # Wait a moment for emulator to start
            time.sleep(5)
            
            if self.emulator_process.poll() is None:
                logger.info("FUSE emulator started successfully")
                
                # Start Ultra HD streaming
                await self.start_ultra_hd_streaming()
                return True
            else:
                logger.error("FUSE emulator failed to start")
                return False
                
        except Exception as e:
            logger.error(f"Failed to start emulator: {e}")
            return False

    async def start_ultra_hd_streaming(self):
        """Start Ultra HD video streaming to both web and YouTube"""
        try:
            # Start scaled web HLS stream
            logger.info(f"Starting Ultra HD web HLS stream: {self.capture_size} -> {self.stream_resolution}")
            
            web_ffmpeg_cmd = [
                'ffmpeg', '-y',
                '-f', 'x11grab',
                '-video_size', self.display_size,
                '-framerate', '25',
                '-i', ':99.0+0,0',
                '-vf', f'scale={self.stream_resolution}:flags={self.scaling_algorithm}',
                '-c:v', 'libx264',
                '-preset', 'medium',  # Better quality for Ultra HD
                '-crf', '18',  # High quality
                '-maxrate', self.stream_bitrate,
                '-bufsize', f'{int(self.stream_bitrate[:-1]) * 2}k',
                '-g', '50',
                '-keyint_min', '25',
                '-sc_threshold', '0',
                '-f', 'hls',
                '-hls_time', '2',
                '-hls_list_size', '5',
                '-hls_flags', 'delete_segments',
                '/tmp/stream/hls/stream.m3u8'
            ]
            
            self.web_stream_process = subprocess.Popen(web_ffmpeg_cmd)
            logger.info(f"Ultra HD web HLS streaming started: {self.capture_size} -> {self.stream_resolution}")
            
            # Start YouTube RTMP stream if key is provided
            if self.youtube_key:
                logger.info(f"Starting YouTube RTMP stream at {self.stream_resolution}")
                
                youtube_ffmpeg_cmd = [
                    'ffmpeg', '-y',
                    '-f', 'x11grab',
                    '-video_size', self.display_size,
                    '-framerate', '25',
                    '-i', ':99.0+0,0',
                    '-vf', f'scale={self.stream_resolution}:flags={self.scaling_algorithm}',
                    '-c:v', 'libx264',
                    '-preset', 'fast',
                    '-crf', '20',
                    '-maxrate', self.stream_bitrate,
                    '-bufsize', f'{int(self.stream_bitrate[:-1]) * 2}k',
                    '-g', '50',
                    '-keyint_min', '25',
                    '-sc_threshold', '0',
                    '-f', 'flv',
                    f'rtmp://a.rtmp.youtube.com/live2/{self.youtube_key}'
                ]
                
                self.youtube_stream_process = subprocess.Popen(youtube_ffmpeg_cmd)
                logger.info(f"YouTube RTMP streaming started at {self.stream_resolution}")
            
            # Start S3 upload process
            logger.info("Starting S3 upload process for Ultra HD HLS segments")
            await self.start_s3_upload()
            
            logger.info("ZX Spectrum emulator started successfully with Ultra HD streaming outputs")
            
        except Exception as e:
            logger.error(f"Failed to start Ultra HD streaming: {e}")

    async def start_s3_upload(self):
        """Start S3 upload worker for HLS segments"""
        if not self.s3_client:
            logger.error("S3 client not available")
            return
            
        def upload_worker():
            """Background worker to upload HLS segments to S3"""
            hls_dir = Path('/tmp/stream/hls')
            uploaded_files = set()
            
            while True:
                try:
                    # Upload playlist file
                    playlist_file = hls_dir / 'stream.m3u8'
                    if playlist_file.exists():
                        self.s3_client.upload_file(
                            str(playlist_file),
                            self.stream_bucket,
                            'hls/stream.m3u8',
                            ExtraArgs={'ContentType': 'application/vnd.apple.mpegurl'}
                        )
                    
                    # Upload new segment files
                    for ts_file in hls_dir.glob('*.ts'):
                        if ts_file.name not in uploaded_files:
                            self.s3_client.upload_file(
                                str(ts_file),
                                self.stream_bucket,
                                f'hls/{ts_file.name}',
                                ExtraArgs={'ContentType': 'video/mp2t'}
                            )
                            uploaded_files.add(ts_file.name)
                            logger.debug(f"Uploaded Ultra HD segment: {ts_file.name}")
                    
                    # Clean up old files from memory
                    if len(uploaded_files) > 20:
                        uploaded_files = set(list(uploaded_files)[-10:])
                    
                    time.sleep(1)
                    
                except Exception as e:
                    logger.error(f"S3 upload error: {e}")
                    time.sleep(5)
        
        upload_thread = threading.Thread(target=upload_worker, daemon=True)
        upload_thread.start()
        logger.info("S3 upload worker started")

    async def send_key_to_emulator(self, key):
        """Send key press to the emulator"""
        # This would need to be implemented based on FUSE's input method
        logger.info(f"Key press: {key}")

    async def stop_emulator(self):
        """Stop the emulator and all streaming processes"""
        logger.info("Stopping emulator and streaming processes...")
        
        processes = [
            ('emulator', self.emulator_process),
            ('web_stream', self.web_stream_process),
            ('youtube_stream', self.youtube_stream_process),
            ('s3_upload', self.s3_upload_process)
        ]
        
        for name, process in processes:
            if process:
                try:
                    process.terminate()
                    process.wait(timeout=5)
                    logger.info(f"{name} process stopped")
                except subprocess.TimeoutExpired:
                    process.kill()
                    logger.info(f"{name} process killed")
                except Exception as e:
                    logger.error(f"Error stopping {name}: {e}")
        
        self.emulator_process = None
        self.web_stream_process = None
        self.youtube_stream_process = None
        self.s3_upload_process = None

    async def health_check(self, request):
        """Health check endpoint"""
        status = {
            'status': 'healthy',
            'emulator_running': self.emulator_process is not None,
            'resolution': self.stream_resolution,
            'bitrate': self.stream_bitrate,
            'connected_clients': len(self.connected_clients),
            'timestamp': time.time()
        }
        return web.json_response(status)

    async def start_http_server(self):
        """Start HTTP server for health checks"""
        app = web.Application()
        app.router.add_get('/health', self.health_check)
        
        runner = web.AppRunner(app)
        await runner.setup()
        site = web.TCPSite(runner, '0.0.0.0', 8080)
        await site.start()
        logger.info("HTTP server started on port 8080")

async def main():
    """Main function to start the Ultra HD emulator server"""
    emulator = SpectrumEmulatorUltraHD()
    
    # Auto-start emulator with Ultra HD scaling
    logger.info("Auto-starting emulator with Ultra HD scaling...")
    success = await emulator.start_emulator()
    if success:
        logger.info(f"Emulator auto-started successfully at {emulator.stream_resolution}")
    else:
        logger.error("Failed to auto-start emulator")
    
    # Start HTTP server
    await emulator.start_http_server()
    
    # Start WebSocket server
    logger.info("Starting WebSocket server...")
    start_server = websockets.serve(emulator.handle_websocket, "0.0.0.0", 8765)
    
    logger.info(f"WebSocket server started on port 8765 - ZX Spectrum Emulator ready with {emulator.stream_resolution} Ultra HD scaling!")
    
    # Run forever
    await asyncio.gather(
        start_server,
        asyncio.Event().wait()  # Run forever
    )

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Server stopped by user")
    except Exception as e:
        logger.error(f"Server error: {e}")
