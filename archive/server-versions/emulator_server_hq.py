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

class SpectrumEmulatorHQ:
    def __init__(self):
        self.connected_clients = set()
        self.emulator_process = None
        self.web_stream_process = None
        self.youtube_stream_process = None
        self.s3_upload_process = None
        self.stream_dir = Path('/tmp/stream')
        self.stream_dir.mkdir(exist_ok=True)
        
        # Get high quality configuration from environment
        self.capture_size = os.getenv('CAPTURE_SIZE', '512x384')
        self.capture_offset = os.getenv('CAPTURE_OFFSET', '0,0')
        self.display_size = os.getenv('DISPLAY_SIZE', '1024x768')
        self.stream_bucket = os.getenv('STREAM_BUCKET', 'spectrum-emulator-stream-dev-043309319786')
        self.youtube_key = os.getenv('YOUTUBE_STREAM_KEY', '')
        
        # High quality streaming configuration
        self.output_resolution = os.getenv('OUTPUT_RESOLUTION', '1920x1080')  # Full HD output
        self.video_bitrate = os.getenv('VIDEO_BITRATE', '5000k')  # 5 Mbps for HLS
        self.youtube_bitrate = os.getenv('YOUTUBE_BITRATE', '6000k')  # 6 Mbps for YouTube
        self.emulator_native_size = '256x192'  # ZX Spectrum native resolution
        
        # Initialize S3 client
        try:
            self.s3_client = boto3.client('s3')
            logger.info(f'S3 client initialized for bucket: {self.stream_bucket}')
        except Exception as e:
            logger.error(f'Failed to initialize S3 client: {e}')
            self.s3_client = None
        
        logger.info(f'HIGH QUALITY CONFIG: display={self.display_size}, output={self.output_resolution}')
        logger.info(f'BITRATES: HLS={self.video_bitrate}, YouTube={self.youtube_bitrate}')

    def test_sdl_environment(self):
        """Test if SDL2 environment is properly configured"""
        try:
            logger.info('Testing SDL2 environment for high quality streaming...')
            
            # Check environment variables
            display = os.getenv('DISPLAY')
            sdl_video = os.getenv('SDL_VIDEODRIVER')
            sdl_audio = os.getenv('SDL_AUDIODRIVER')
            
            logger.info(f'Environment: DISPLAY={display}, SDL_VIDEODRIVER={sdl_video}, SDL_AUDIODRIVER={sdl_audio}')
            
            # Test X11 connection
            result = subprocess.run(['xdpyinfo'], env={'DISPLAY': display}, 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                logger.info('X11 display test: SUCCESS')
            else:
                logger.warning(f'X11 display test failed: {result.stderr}')
                return False
            
            # Test FUSE availability
            result = subprocess.run(['which', 'fuse-sdl'], capture_output=True, text=True)
            if result.returncode == 0:
                logger.info(f'FUSE emulator found at: {result.stdout.strip()}')
            else:
                logger.error('FUSE emulator not found')
                return False
            
            return True
            
        except Exception as e:
            logger.error(f'SDL environment test failed: {e}')
            return False

    def start_emulator(self):
        try:
            if self.emulator_process:
                logger.info('Emulator already running')
                return True

            # Test SDL environment first
            if not self.test_sdl_environment():
                logger.error('SDL environment test failed, starting with high quality test pattern')
                self.start_web_stream_with_hq_test_pattern()
                self.start_youtube_stream_hq()
                self.start_s3_upload()
                return False

            logger.info('Starting FUSE ZX Spectrum emulator with HIGH QUALITY configuration')
            
            # Enhanced environment for FUSE
            fuse_env = os.environ.copy()
            fuse_env.update({
                'DISPLAY': ':99',
                'SDL_VIDEODRIVER': 'x11',
                'SDL_AUDIODRIVER': 'pulse',
                'XAUTHORITY': '/tmp/.Xauth'
            })
            
            # Start FUSE with high quality settings
            self.emulator_process = subprocess.Popen([
                'fuse-sdl', 
                '--machine', '48', 
                '--graphics-filter', 'none', 
                '--sound', 
                '--no-confirm-actions',
                '--full-screen'
            ], env=fuse_env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            
            # Wait and check if FUSE started successfully
            time.sleep(5)
            
            if self.emulator_process.poll() is not None:
                stdout, stderr = self.emulator_process.communicate()
                logger.error(f'FUSE emulator failed to start:')
                logger.error(f'STDOUT: {stdout.decode()}')
                logger.error(f'STDERR: {stderr.decode()}')
                self.emulator_process = None
                
                # Start high quality streaming with test pattern
                logger.info('Starting HIGH QUALITY streaming with test pattern due to FUSE failure')
                self.start_web_stream_with_hq_test_pattern()
                self.start_youtube_stream_hq()
                self.start_s3_upload()
                return False
            else:
                logger.info('FUSE emulator started successfully')
                time.sleep(3)
                
                # Start high quality streaming with proper scaling
                self.start_web_stream_hq()
                self.start_youtube_stream_hq()
                self.start_s3_upload()
                logger.info(f'ZX Spectrum emulator started with HIGH QUALITY streaming at {self.output_resolution}')
                return True
            
        except Exception as e:
            logger.error(f'Failed to start emulator: {e}')
            self.stop_emulator()
            # Fallback to high quality test pattern streaming
            self.start_web_stream_with_hq_test_pattern()
            self.start_youtube_stream_hq()
            self.start_s3_upload()
            return False

    def start_web_stream_hq(self):
        """Start HIGH QUALITY streaming with proper scaling from full display"""
        try:
            logger.info(f'Starting HIGH QUALITY HLS stream: {self.display_size} -> {self.output_resolution} @ {self.video_bitrate}')
            stream_file = self.stream_dir / 'stream.m3u8'
            
            # High quality capture and encoding
            self.web_stream_process = subprocess.Popen([
                'ffmpeg', '-y',
                '-f', 'x11grab',
                '-video_size', self.display_size,  # Capture larger display
                '-framerate', '25',
                '-i', ':99.0+0,0',
                '-f', 'pulse',
                '-i', 'default',
                # High quality video processing
                '-vf', f'scale={self.output_resolution}:flags=lanczos',  # High quality scaling
                '-c:v', 'libx264',
                '-preset', 'medium',  # Better quality than fast
                '-tune', 'zerolatency',
                '-profile:v', 'high',  # High profile for better compression
                '-level', '4.1',
                '-g', '50',
                '-keyint_min', '25',
                '-sc_threshold', '0',
                '-b:v', self.video_bitrate,  # High bitrate
                '-maxrate', f'{int(self.video_bitrate[:-1]) + 1000}k',  # Maxrate = bitrate + 1Mbps
                '-bufsize', f'{int(self.video_bitrate[:-1]) * 2}k',  # Buffer = 2x bitrate
                '-pix_fmt', 'yuv420p',
                # High quality audio
                '-c:a', 'aac',
                '-b:a', '192k',  # Higher audio bitrate
                '-ar', '48000',  # Higher sample rate
                # HLS output
                '-f', 'hls',
                '-hls_time', '2',
                '-hls_list_size', '5',
                '-hls_flags', 'delete_segments',
                str(stream_file)
            ])
            logger.info(f'HIGH QUALITY HLS streaming started: {self.output_resolution} @ {self.video_bitrate}')
            
        except Exception as e:
            logger.error(f'Failed to start high quality web stream: {e}')

    def start_web_stream_with_hq_test_pattern(self):
        """Start HIGH QUALITY streaming with test pattern"""
        try:
            logger.info(f'Starting HIGH QUALITY test pattern stream: {self.output_resolution} @ {self.video_bitrate}')
            stream_file = self.stream_dir / 'stream.m3u8'
            
            # High quality test pattern with retro gaming colors
            self.web_stream_process = subprocess.Popen([
                'ffmpeg', '-y',
                '-f', 'lavfi',
                '-i', f'testsrc2=size={self.output_resolution}:rate=25:duration=0',
                '-f', 'lavfi', 
                '-i', 'sine=frequency=1000:duration=0',
                # High quality encoding
                '-c:v', 'libx264',
                '-preset', 'medium',
                '-tune', 'zerolatency',
                '-profile:v', 'high',
                '-level', '4.1',
                '-g', '50',
                '-keyint_min', '25',
                '-sc_threshold', '0',
                '-b:v', self.video_bitrate,
                '-maxrate', f'{int(self.video_bitrate[:-1]) + 1000}k',
                '-bufsize', f'{int(self.video_bitrate[:-1]) * 2}k',
                '-pix_fmt', 'yuv420p',
                '-c:a', 'aac',
                '-b:a', '192k',
                '-ar', '48000',
                '-f', 'hls',
                '-hls_time', '2',
                '-hls_list_size', '5',
                '-hls_flags', 'delete_segments',
                str(stream_file)
            ])
            logger.info(f'HIGH QUALITY test pattern streaming started at {self.output_resolution} @ {self.video_bitrate}')
            
        except Exception as e:
            logger.error(f'Failed to start high quality test pattern stream: {e}')

    def start_youtube_stream_hq(self):
        if not self.youtube_key:
            logger.info('No YouTube stream key provided, skipping YouTube streaming')
            return
            
        try:
            logger.info(f'Starting HIGH QUALITY YouTube RTMP stream at {self.output_resolution} @ {self.youtube_bitrate}')
            
            # Use test pattern if emulator failed, otherwise use X11 capture
            if self.emulator_process is None:
                # High quality test pattern for YouTube
                input_args = [
                    '-f', 'lavfi',
                    '-i', f'testsrc2=size={self.output_resolution}:rate=25:duration=0',
                    '-f', 'lavfi', 
                    '-i', 'sine=frequency=1000:duration=0'
                ]
            else:
                # High quality X11 capture for YouTube
                input_args = [
                    '-f', 'x11grab',
                    '-video_size', self.display_size,
                    '-framerate', '25',
                    '-i', ':99.0+0,0',
                    '-f', 'pulse',
                    '-i', 'default'
                ]
            
            # Build high quality FFmpeg command
            ffmpeg_cmd = ['ffmpeg', '-y'] + input_args
            
            # Add high quality scaling if capturing from X11
            if self.emulator_process is not None:
                ffmpeg_cmd.extend([
                    '-vf', f'scale={self.output_resolution}:flags=lanczos'
                ])
            
            # Add high quality encoding settings for YouTube
            ffmpeg_cmd.extend([
                '-c:v', 'libx264',
                '-preset', 'veryfast',  # Balance between quality and CPU usage
                '-tune', 'zerolatency',
                '-profile:v', 'high',
                '-level', '4.1',
                '-g', '50',
                '-keyint_min', '25',
                '-sc_threshold', '0',
                '-b:v', self.youtube_bitrate,  # High bitrate for YouTube
                '-maxrate', f'{int(self.youtube_bitrate[:-1]) + 1000}k',
                '-bufsize', f'{int(self.youtube_bitrate[:-1]) * 2}k',
                '-pix_fmt', 'yuv420p',
                '-c:a', 'aac',
                '-b:a', '192k',
                '-ar', '48000',
                '-f', 'flv',
                f'rtmp://a.rtmp.youtube.com/live2/{self.youtube_key}'
            ])
            
            self.youtube_stream_process = subprocess.Popen(ffmpeg_cmd)
            logger.info(f'HIGH QUALITY YouTube RTMP streaming started at {self.output_resolution} @ {self.youtube_bitrate}')
            
        except Exception as e:
            logger.error(f'Failed to start high quality YouTube stream: {e}')

    def start_s3_upload(self):
        if not self.s3_client:
            logger.warning('S3 client not available, skipping S3 upload')
            return
            
        try:
            logger.info('Starting S3 upload process for HIGH QUALITY HLS segments')
            
            def upload_worker():
                while True:
                    try:
                        # Upload HLS playlist
                        playlist_file = self.stream_dir / 'stream.m3u8'
                        if playlist_file.exists():
                            self.s3_client.upload_file(
                                str(playlist_file),
                                self.stream_bucket,
                                'hls/stream.m3u8',
                                ExtraArgs={'ContentType': 'application/vnd.apple.mpegurl', 'CacheControl': 'no-cache'}
                            )
                        
                        # Upload segment files
                        for segment_file in self.stream_dir.glob('*.ts'):
                            try:
                                self.s3_client.upload_file(
                                    str(segment_file),
                                    self.stream_bucket,
                                    f'hls/{segment_file.name}',
                                    ExtraArgs={'ContentType': 'video/mp2t', 'CacheControl': 'max-age=10'}
                                )
                            except Exception as e:
                                # Ignore individual segment upload errors
                                pass
                        
                        time.sleep(1)
                        
                    except Exception as e:
                        logger.error(f'S3 upload error: {e}')
                        time.sleep(5)
            
            upload_thread = threading.Thread(target=upload_worker, daemon=True)
            upload_thread.start()
            logger.info('S3 upload worker started for HIGH QUALITY segments')
            
        except Exception as e:
            logger.error(f'Failed to start S3 upload: {e}')

    def stop_emulator(self):
        try:
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
                        logger.info(f'{name} process stopped')
                    except subprocess.TimeoutExpired:
                        process.kill()
                        logger.info(f'{name} process killed')
                    except Exception as e:
                        logger.error(f'Error stopping {name}: {e}')
            
            self.emulator_process = None
            self.web_stream_process = None
            self.youtube_stream_process = None
            self.s3_upload_process = None
            
        except Exception as e:
            logger.error(f'Error stopping emulator: {e}')

    async def handle_websocket(self, websocket, path):
        self.connected_clients.add(websocket)
        logger.info('New WebSocket client connected to HIGH QUALITY server')
        
        try:
            # Send initial status
            await websocket.send(json.dumps({
                'type': 'connected',
                'emulator_running': self.emulator_process is not None,
                'output_resolution': self.output_resolution,
                'video_bitrate': self.video_bitrate,
                'youtube_bitrate': self.youtube_bitrate,
                'quality': 'HIGH_QUALITY'
            }))
            
            async for message in websocket:
                try:
                    data = json.loads(message)
                    logger.info(f'Received message: {data}')
                    
                    if data.get('type') == 'start_emulator':
                        success = self.start_emulator()
                        await websocket.send(json.dumps({
                            'type': 'emulator_status',
                            'running': success,
                            'message': 'HIGH QUALITY emulator started' if success else 'HIGH QUALITY test pattern started',
                            'output_resolution': self.output_resolution,
                            'video_bitrate': self.video_bitrate,
                            'youtube_bitrate': self.youtube_bitrate
                        }))
                    
                    elif data.get('type') == 'stop_emulator':
                        self.stop_emulator()
                        await websocket.send(json.dumps({
                            'type': 'emulator_status',
                            'running': False,
                            'message': 'HIGH QUALITY emulator stopped'
                        }))
                    
                    elif data.get('type') == 'status':
                        await websocket.send(json.dumps({
                            'type': 'emulator_status',
                            'running': self.emulator_process is not None,
                            'message': 'HIGH QUALITY status check',
                            'output_resolution': self.output_resolution,
                            'video_bitrate': self.video_bitrate,
                            'youtube_bitrate': self.youtube_bitrate
                        }))
                    
                    elif data.get('type') == 'key_press':
                        # Handle key press (to be implemented)
                        key = data.get('key')
                        logger.info(f'Key press: {key}')
                        
                except json.JSONDecodeError:
                    logger.error(f'Invalid JSON received: {message}')
                except Exception as e:
                    logger.error(f'Error handling message: {e}')
                    
        except websockets.exceptions.ConnectionClosed:
            logger.info('WebSocket client disconnected')
        finally:
            self.connected_clients.discard(websocket)

    async def health_check(self, request):
        return web.Response(text=f'OK - HIGH QUALITY Emulator server running at {self.output_resolution} @ {self.video_bitrate}', status=200)

    async def start_streaming(self, request):
        success = self.start_emulator()
        return web.json_response({
            'success': success,
            'message': 'HIGH QUALITY streaming started' if success else 'HIGH QUALITY test pattern started',
            'output_resolution': self.output_resolution,
            'video_bitrate': self.video_bitrate,
            'youtube_bitrate': self.youtube_bitrate
        })

    def run(self):
        # Auto-start high quality emulator
        logger.info(f'Auto-starting HIGH QUALITY emulator at {self.output_resolution}...')
        success = self.start_emulator()
        if success:
            logger.info(f'HIGH QUALITY emulator auto-started successfully at {self.output_resolution} @ {self.video_bitrate}')
        else:
            logger.info(f'HIGH QUALITY test pattern started at {self.output_resolution} @ {self.video_bitrate}')
        
        # Start HTTP server for health checks
        app = web.Application()
        app.router.add_get('/health', self.health_check)
        app.router.add_post('/start_streaming', self.start_streaming)
        
        async def init_app():
            runner = web.AppRunner(app)
            await runner.setup()
            site = web.TCPSite(runner, '0.0.0.0', 8080)
            await site.start()
            logger.info('HIGH QUALITY HTTP server started on port 8080')
        
        # Start WebSocket server
        async def start_servers():
            await init_app()
            await websockets.serve(self.handle_websocket, '0.0.0.0', 8765)
            logger.info(f'HIGH QUALITY WebSocket server started on port 8765 - ZX Spectrum Emulator ready with {self.output_resolution} @ {self.video_bitrate}!')
        
        # Run the event loop
        loop = asyncio.get_event_loop()
        loop.run_until_complete(start_servers())
        loop.run_forever()

if __name__ == '__main__':
    emulator = SpectrumEmulatorHQ()
    emulator.run()
