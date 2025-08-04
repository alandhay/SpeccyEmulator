#!/usr/bin/env python3
"""
ZX Spectrum Emulator Server - Corrected to Match Working Local Tests
===================================================================

This version exactly matches our proven working local test configuration:
- Virtual display: 800x600x24 (same as local)
- FUSE positioning: Proper window placement
- Capture area: Exact same as working local tests
- Scaling: Matches local adjustable scaling approach
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

class CorrectedEmulatorServer:
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
        self.version = os.getenv('VERSION', '1.0.0-corrected')
        
        # CORRECTED: Match exact working local test configuration
        self.virtual_display_size = '800x600x24'  # Exact match to local
        self.capture_w = 320
        self.capture_h = 240
        # CORRECTED: Use same offset calculation as local tests
        self.offset_x = 240  # (800-320)/2 = 240
        self.offset_y = 180  # (600-240)/2 = 180
        self.scale_factor = float(os.getenv('SCALE_FACTOR', '1.8'))
        self.frame_rate = 30
        
        logger.info("🔧 Starting CORRECTED ZX Spectrum Emulator Server")
        logger.info(f"Version: {self.version}")
        logger.info(f"Strategy: Exact match to working local test configuration")
        logger.info("")
        logger.info("🎯 CORRECTED Configuration (matching local tests):")
        logger.info(f"  Virtual Display: {self.virtual_display_size}")
        logger.info(f"  Capture Size: {self.capture_w}x{self.capture_h}")
        logger.info(f"  Capture Offset: +{self.offset_x},{self.offset_y}")
        logger.info(f"  Scale Factor: {self.scale_factor}x")
        logger.info(f"  Frame Rate: {self.frame_rate} FPS")

    def setup_s3_client(self):
        """Initialize S3 client for HLS uploads"""
        try:
            self.s3_client = boto3.client('s3')
            logger.info("S3 client initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize S3 client: {e}")
            raise

    def start_xvfb(self):
        """Start virtual framebuffer - CORRECTED to match local tests exactly"""
        try:
            logger.info("Starting Xvfb virtual framebuffer (matching local test setup)...")
            
            # CORRECTED: Exact same command as working local tests
            self.xvfb_process = subprocess.Popen([
                'Xvfb', ':99', 
                '-screen', '0', self.virtual_display_size,
                '-ac'
            ])
            
            time.sleep(3)
            
            result = subprocess.run(['xdpyinfo', '-display', ':99'], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                logger.info("✅ Xvfb started successfully on display :99")
            else:
                raise Exception("Xvfb failed to start properly")
                
        except Exception as e:
            logger.error(f"Failed to start Xvfb: {e}")
            raise

    def start_emulator(self):
        """Start FUSE emulator - CORRECTED to match local test behavior"""
        try:
            logger.info("Starting FUSE emulator (matching local test setup)...")
            
            # CORRECTED: Ensure proper user context
            fuse_config_dir = os.path.join(os.getenv('HOME', '/tmp'), '.fuse')
            os.makedirs(fuse_config_dir, exist_ok=True)
            
            # CORRECTED: Exact same FUSE command as local tests
            fuse_cmd = [
                'fuse-sdl',
                '--machine', '48',
                '--no-sound'
            ]
            
            # CORRECTED: Same environment as local tests
            fuse_env = dict(os.environ)
            fuse_env.update({
                'DISPLAY': ':99',
                'SDL_VIDEODRIVER': 'x11',
                'SDL_AUDIODRIVER': 'dummy',
                'HOME': os.getenv('HOME', '/tmp')
            })
            
            logger.info(f"FUSE command: {' '.join(fuse_cmd)}")
            
            self.emulator_process = subprocess.Popen(
                fuse_cmd,
                env=fuse_env
            )
            
            # CORRECTED: Same wait time as local tests
            logger.info("⏳ Waiting for FUSE to initialize (5 seconds, same as local tests)...")
            time.sleep(5)
            
            if self.emulator_process.poll() is None:
                logger.info("✅ FUSE emulator started successfully")
            else:
                raise Exception("FUSE emulator exited during startup")
            
        except Exception as e:
            logger.error(f"Failed to start FUSE emulator: {e}")
            raise

    def start_ffmpeg_hls(self):
        """Start FFmpeg HLS - CORRECTED to match exact working local test command"""
        try:
            logger.info("Starting FFmpeg HLS (matching exact local test command)...")
            
            # CORRECTED: Exact same FFmpeg command as working local tests
            ffmpeg_cmd = [
                'ffmpeg',
                # VIDEO INPUT: Exact match to local test
                '-f', 'x11grab',
                '-draw_mouse', '0',
                '-video_size', f'{self.capture_w}x{self.capture_h}',
                '-framerate', str(self.frame_rate),
                '-i', f':99.0+{self.offset_x},{self.offset_y}',
                
                # AUDIO INPUT: Exact match to local test
                '-f', 'lavfi',
                '-i', 'anullsrc=channel_layout=stereo:sample_rate=44100',
                
                # VIDEO FILTER: Exact match to working local test
                '-vf', f'scale=iw*{self.scale_factor}:ih*{self.scale_factor}:flags=neighbor,scale=1280:720:flags=lanczos:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2:black,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:text=\'🔴 LIVE ZX SPECTRUM {self.scale_factor}X %{{localtime}}\':fontcolor=yellow:fontsize=36:x=w-text_w-20:y=20:box=1:boxcolor=black@0.7:boxborderw=3',
                
                # VIDEO CODEC: Exact match to local test
                '-c:v', 'libx264',
                '-preset', 'veryfast',
                '-tune', 'zerolatency',
                '-pix_fmt', 'yuv420p',
                
                # AUDIO CODEC: Exact match to local test
                '-c:a', 'aac',
                '-b:a', '128k',
                
                # HLS OUTPUT: Same as local test
                '-f', 'hls',
                '-hls_time', '2',
                '-hls_list_size', '5',
                '-hls_flags', 'delete_segments',
                '-hls_segment_filename', '/tmp/stream/stream%d.ts',
                '/tmp/stream/stream.m3u8'
            ]
            
            logger.info(f"CORRECTED FFmpeg HLS command: {' '.join(ffmpeg_cmd)}")
            
            os.makedirs('/tmp/stream', exist_ok=True)
            
            self.ffmpeg_hls_process = subprocess.Popen(
                ffmpeg_cmd,
                env=dict(os.environ, DISPLAY=':99')
            )
            
            time.sleep(3)
            logger.info("✅ FFmpeg HLS started successfully (matching local test)")
            
        except Exception as e:
            logger.error(f"Failed to start FFmpeg HLS: {e}")
            raise

    def start_ffmpeg_youtube(self):
        """Start FFmpeg YouTube - CORRECTED to match local test"""
        if not self.youtube_key:
            logger.info("No YouTube stream key provided, skipping RTMP stream")
            return
            
        try:
            logger.info("Starting YouTube RTMP (matching local test)...")
            
            # CORRECTED: Exact same YouTube command as local test
            youtube_cmd = [
                'ffmpeg', '-y',
                # INPUT: Same as HLS
                '-f', 'x11grab',
                '-draw_mouse', '0',
                '-video_size', f'{self.capture_w}x{self.capture_h}',
                '-framerate', str(self.frame_rate),
                '-i', f':99.0+{self.offset_x},{self.offset_y}',
                
                # AUDIO INPUT: Same as HLS
                '-f', 'lavfi',
                '-i', 'anullsrc=channel_layout=stereo:sample_rate=44100',
                
                # VIDEO FILTER: Same as HLS
                '-vf', f'scale=iw*{self.scale_factor}:ih*{self.scale_factor}:flags=neighbor,scale=1280:720:flags=lanczos:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2:black,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:text=\'🔴 LIVE ZX SPECTRUM {self.scale_factor}X %{{localtime}}\':fontcolor=yellow:fontsize=36:x=w-text_w-20:y=20:box=1:boxcolor=black@0.7:boxborderw=3',
                
                # VIDEO ENCODING: Optimized for streaming
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
                
                # AUDIO ENCODING: Same as HLS
                '-c:a', 'aac',
                '-b:a', '128k',
                '-ar', '44100',
                
                # RTMP OUTPUT: Same as local test
                '-f', 'flv',
                f'rtmp://a.rtmp.youtube.com/live2/{self.youtube_key}'
            ]
            
            logger.info(f"CORRECTED YouTube command: {' '.join(youtube_cmd)}")
            
            self.ffmpeg_youtube_process = subprocess.Popen(
                youtube_cmd,
                env=dict(os.environ, DISPLAY=':99')
            )
            
            time.sleep(3)
            logger.info("✅ YouTube RTMP streaming started successfully (matching local test)")
            
        except Exception as e:
            logger.error(f"Failed to start YouTube streaming: {e}")
            raise

    def upload_hls_segments(self):
        """Upload HLS segments to S3"""
        while self.running:
            try:
                if os.path.exists('/tmp/stream'):
                    for filename in os.listdir('/tmp/stream'):
                        if filename.endswith('.ts') or filename.endswith('.m3u8'):
                            local_path = f'/tmp/stream/{filename}'
                            s3_key = f'hls/{filename}'
                            
                            try:
                                self.s3_client.upload_file(
                                    local_path, 
                                    self.stream_bucket, 
                                    s3_key,
                                    ExtraArgs={
                                        'ContentType': 'application/x-mpegURL' if filename.endswith('.m3u8') else 'video/MP2T',
                                        'CacheControl': 'max-age=1'
                                    }
                                )
                            except FileNotFoundError:
                                continue
                            except Exception as e:
                                logger.error(f"Failed to upload {filename}: {e}")
                
                time.sleep(1)
                
            except Exception as e:
                logger.error(f"Error in upload thread: {e}")
                time.sleep(5)

    async def handle_websocket(self, websocket):
        """Handle WebSocket connections"""
        self.websocket_clients.add(websocket)
        logger.info(f"WebSocket client connected. Total clients: {len(self.websocket_clients)}")
        
        try:
            await websocket.send(json.dumps({
                'type': 'connected',
                'emulator_running': self.emulator_process is not None and self.emulator_process.poll() is None,
                'version': self.version,
                'strategy': 'corrected-local-match'
            }))
            
            async for message in websocket:
                try:
                    data = json.loads(message)
                    await self.handle_message(websocket, data)
                except json.JSONDecodeError:
                    await websocket.send(json.dumps({
                        'type': 'error',
                        'message': 'Invalid JSON'
                    }))
                    
        except websockets.exceptions.ConnectionClosed:
            pass
        finally:
            self.websocket_clients.discard(websocket)

    async def handle_message(self, websocket, data):
        """Handle WebSocket messages"""
        message_type = data.get('type')
        
        if message_type == 'status':
            status = {
                'type': 'status',
                'processes': {
                    'xvfb': self.xvfb_process is not None and self.xvfb_process.poll() is None,
                    'emulator': self.emulator_process is not None and self.emulator_process.poll() is None,
                    'ffmpeg_hls': self.ffmpeg_hls_process is not None and self.ffmpeg_hls_process.poll() is None,
                    'ffmpeg_youtube': self.ffmpeg_youtube_process is not None and self.ffmpeg_youtube_process.poll() is None
                },
                'version': self.version,
                'strategy': 'corrected-local-match'
            }
            await websocket.send(json.dumps(status))

    async def health_check(self, request):
        """Health check endpoint"""
        processes = {
            'xvfb': self.xvfb_process is not None and self.xvfb_process.poll() is None,
            'emulator': self.emulator_process is not None and self.emulator_process.poll() is None,
            'ffmpeg_hls': self.ffmpeg_hls_process is not None and self.ffmpeg_hls_process.poll() is None,
            'ffmpeg_youtube': self.ffmpeg_youtube_process is not None and self.ffmpeg_youtube_process.poll() is None
        }
        
        return web.json_response({
            'status': 'healthy',
            'version': self.version,
            'strategy': 'corrected-local-match',
            'processes': processes
        })

    def cleanup(self):
        """Clean up all processes"""
        logger.info("Cleaning up processes...")
        
        self.running = False
        
        processes = [
            ('FFmpeg YouTube', self.ffmpeg_youtube_process),
            ('FFmpeg HLS', self.ffmpeg_hls_process),
            ('FUSE Emulator', self.emulator_process),
            ('Xvfb', self.xvfb_process)
        ]
        
        for name, process in processes:
            if process and process.poll() is None:
                logger.info(f"Terminating {name}...")
                try:
                    process.terminate()
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    logger.warning(f"Force killing {name}...")
                    process.kill()

    async def start_server(self):
        """Start the corrected server"""
        try:
            logger.info("🚀 Starting corrected server (matching local test setup)...")
            
            self.setup_s3_client()
            self.start_xvfb()
            self.start_emulator()
            self.start_ffmpeg_hls()
            self.start_ffmpeg_youtube()
            
            self.upload_thread = threading.Thread(target=self.upload_hls_segments, daemon=True)
            self.upload_thread.start()
            
            # Set up HTTP server for health checks
            app = web.Application()
            app.router.add_get('/health', self.health_check)
            
            runner = web.AppRunner(app)
            await runner.setup()
            site = web.TCPSite(runner, '0.0.0.0', 8080)
            await site.start()
            
            logger.info("✅ HTTP health check server started on port 8080")
            
            # Start WebSocket server
            websocket_server = await websockets.serve(
                self.handle_websocket,
                '0.0.0.0',
                8765
            )
            
            logger.info("✅ WebSocket server started on port 8765")
            logger.info("🔧 CORRECTED ZX Spectrum Emulator Server is fully operational!")
            logger.info("📺 Configuration matches proven working local tests")
            
            await websocket_server.wait_closed()
            
        except Exception as e:
            logger.error(f"Failed to start server: {e}")
            self.cleanup()
            raise

def main():
    """Main entry point"""
    server = CorrectedEmulatorServer()
    
    def signal_handler(signum, frame):
        logger.info("Received shutdown signal")
        server.cleanup()
        sys.exit(0)
    
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)
    
    try:
        asyncio.run(server.start_server())
    except KeyboardInterrupt:
        logger.info("Server stopped by user")
    except Exception as e:
        logger.error(f"Server error: {e}")
        sys.exit(1)
    finally:
        server.cleanup()

if __name__ == '__main__':
    main()
