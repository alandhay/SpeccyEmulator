#!/usr/bin/env python3
"""
Fix for ZX Spectrum Emulator - Combines segment naming fix with proper FUSE integration
This script addresses both the HLS segment naming issue and the FUSE emulator X11 display issue
"""

import os
import sys
import subprocess
import time
import signal
import threading
import asyncio
import websockets
import json
import logging
from pathlib import Path

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class SpectrumEmulatorServer:
    def __init__(self):
        self.emulator_process = None
        self.xvfb_process = None
        self.ffmpeg_process = None
        self.pulseaudio_process = None
        self.clients = set()
        self.emulator_running = False
        
    def start_xvfb(self):
        """Start virtual X11 display server"""
        try:
            logger.info("Starting Xvfb virtual display...")
            self.xvfb_process = subprocess.Popen([
                'Xvfb', ':99', 
                '-screen', '0', '512x384x24',
                '-ac', '+extension', 'GLX'
            ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            
            # Wait a moment for Xvfb to start
            time.sleep(2)
            
            # Verify Xvfb is running
            if self.xvfb_process.poll() is None:
                logger.info("Xvfb started successfully on display :99")
                return True
            else:
                logger.error("Xvfb failed to start")
                return False
                
        except Exception as e:
            logger.error(f"Failed to start Xvfb: {e}")
            return False
    
    def start_pulseaudio(self):
        """Start PulseAudio server"""
        try:
            logger.info("Starting PulseAudio...")
            
            # Create pulse runtime directory
            os.makedirs('/tmp/pulse', exist_ok=True)
            os.environ['PULSE_RUNTIME_PATH'] = '/tmp/pulse'
            
            self.pulseaudio_process = subprocess.Popen([
                'pulseaudio', '--system=false', '--exit-idle-time=-1',
                '--disable-shm', '--verbose'
            ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            
            time.sleep(2)
            
            if self.pulseaudio_process.poll() is None:
                logger.info("PulseAudio started successfully")
                return True
            else:
                logger.error("PulseAudio failed to start")
                return False
                
        except Exception as e:
            logger.error(f"Failed to start PulseAudio: {e}")
            return False
    
    def start_ffmpeg(self):
        """Start FFmpeg with corrected HLS segment naming"""
        try:
            logger.info("Starting FFmpeg with corrected segment naming...")
            
            # Create stream directory
            os.makedirs('/tmp/stream', exist_ok=True)
            
            # FFmpeg command with CORRECTED segment naming
            ffmpeg_cmd = [
                'ffmpeg',
                '-f', 'x11grab',
                '-video_size', '256x192',
                '-framerate', '25',
                '-i', ':99.0+0,0',
                '-f', 'pulse',
                '-i', 'default',
                '-c:v', 'libx264',
                '-preset', 'ultrafast',
                '-tune', 'zerolatency',
                '-pix_fmt', 'yuv420p',
                '-c:a', 'aac',
                '-b:a', '128k',
                '-f', 'hls',
                '-hls_time', '2',
                '-hls_list_size', '5',
                '-hls_flags', 'delete_segments',
                # CRITICAL FIX: Use stream%d.ts naming pattern to match upload expectations
                '-hls_segment_filename', '/tmp/stream/stream%d.ts',
                '/tmp/stream/stream.m3u8'
            ]
            
            logger.info(f"FFmpeg command: {' '.join(ffmpeg_cmd)}")
            
            self.ffmpeg_process = subprocess.Popen(
                ffmpeg_cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            
            # Check if FFmpeg started successfully
            time.sleep(3)
            if self.ffmpeg_process.poll() is None:
                logger.info("FFmpeg started successfully with corrected segment naming")
                return True
            else:
                stderr_output = self.ffmpeg_process.stderr.read().decode()
                logger.error(f"FFmpeg failed to start: {stderr_output}")
                return False
                
        except Exception as e:
            logger.error(f"Failed to start FFmpeg: {e}")
            return False
    
    def start_emulator(self):
        """Start FUSE ZX Spectrum emulator"""
        try:
            if self.emulator_running:
                logger.info("Emulator already running")
                return True
                
            logger.info("Starting FUSE ZX Spectrum emulator...")
            
            # Verify FUSE is available
            fuse_path = subprocess.run(['which', 'fuse-sdl'], capture_output=True, text=True)
            if fuse_path.returncode != 0:
                logger.error("FUSE emulator not found")
                return False
                
            logger.info(f"FUSE emulator found at: {fuse_path.stdout.strip()}")
            
            # Set environment for emulator
            env = os.environ.copy()
            env.update({
                'DISPLAY': ':99',
                'SDL_VIDEODRIVER': 'x11',
                'SDL_AUDIODRIVER': 'pulse'
            })
            
            logger.info(f"Environment: DISPLAY={env.get('DISPLAY')}, SDL_VIDEODRIVER={env.get('SDL_VIDEODRIVER')}, SDL_AUDIODRIVER={env.get('SDL_AUDIODRIVER')}")
            
            # Start FUSE emulator
            self.emulator_process = subprocess.Popen([
                'fuse-sdl',
                '--machine', '48',
                '--no-sound',  # Disable sound initially to avoid issues
                '--graphics-filter', 'none'
            ], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            
            # Wait and check if emulator started
            time.sleep(3)
            if self.emulator_process.poll() is None:
                logger.info("FUSE emulator started successfully")
                self.emulator_running = True
                return True
            else:
                stderr_output = self.emulator_process.stderr.read().decode()
                logger.error(f"FUSE emulator failed to start: {stderr_output}")
                return False
                
        except Exception as e:
            logger.error(f"Failed to start emulator: {e}")
            return False
    
    def stop_all_processes(self):
        """Stop all running processes"""
        logger.info("Stopping all processes...")
        
        processes = [
            ('Emulator', self.emulator_process),
            ('FFmpeg', self.ffmpeg_process),
            ('PulseAudio', self.pulseaudio_process),
            ('Xvfb', self.xvfb_process)
        ]
        
        for name, process in processes:
            if process and process.poll() is None:
                logger.info(f"Stopping {name}...")
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    logger.warning(f"Force killing {name}...")
                    process.kill()
    
    async def handle_websocket(self, websocket, path):
        """Handle WebSocket connections"""
        logger.info(f"New WebSocket connection from {websocket.remote_address}")
        self.clients.add(websocket)
        
        try:
            # Send initial status
            await websocket.send(json.dumps({
                'type': 'connected',
                'emulator_running': self.emulator_running
            }))
            
            async for message in websocket:
                try:
                    data = json.loads(message)
                    await self.handle_message(websocket, data)
                except json.JSONDecodeError:
                    logger.error(f"Invalid JSON received: {message}")
                    
        except websockets.exceptions.ConnectionClosed:
            logger.info("WebSocket connection closed")
        finally:
            self.clients.discard(websocket)
    
    async def handle_message(self, websocket, data):
        """Handle WebSocket messages"""
        message_type = data.get('type')
        logger.info(f"Received message: {data}")
        
        if message_type == 'start_emulator':
            success = self.start_emulator()
            await websocket.send(json.dumps({
                'type': 'emulator_status',
                'running': success,
                'message': 'Emulator started' if success else 'Failed to start emulator'
            }))
            
        elif message_type == 'key_press':
            key = data.get('key')
            if key and self.emulator_running:
                logger.info(f"Key press received: {key}")
                # TODO: Send key to emulator via FIFO or other mechanism
                await websocket.send(json.dumps({
                    'type': 'key_acknowledged',
                    'key': key
                }))
            
        elif message_type == 'status':
            await websocket.send(json.dumps({
                'type': 'status_response',
                'emulator_running': self.emulator_running,
                'xvfb_running': self.xvfb_process and self.xvfb_process.poll() is None,
                'ffmpeg_running': self.ffmpeg_process and self.ffmpeg_process.poll() is None
            }))
    
    def start_upload_thread(self):
        """Start thread to upload HLS segments to S3"""
        def upload_segments():
            bucket = os.environ.get('STREAM_BUCKET', 'spectrum-emulator-stream-dev-043309319786')
            
            while True:
                try:
                    # Upload stream files to S3
                    if os.path.exists('/tmp/stream/stream.m3u8'):
                        subprocess.run([
                            'aws', 's3', 'cp', '/tmp/stream/stream.m3u8',
                            f's3://{bucket}/hls/stream.m3u8',
                            '--content-type', 'application/vnd.apple.mpegurl'
                        ], check=False)
                    
                    # Upload segment files
                    for segment_file in Path('/tmp/stream').glob('stream*.ts'):
                        subprocess.run([
                            'aws', 's3', 'cp', str(segment_file),
                            f's3://{bucket}/hls/{segment_file.name}',
                            '--content-type', 'video/mp2t'
                        ], check=False)
                    
                    time.sleep(1)
                    
                except Exception as e:
                    logger.error(f"Upload error: {e}")
                    time.sleep(5)
        
        upload_thread = threading.Thread(target=upload_segments, daemon=True)
        upload_thread.start()
        logger.info("S3 upload thread started")
    
    async def health_check_server(self):
        """Simple HTTP health check server"""
        from aiohttp import web
        
        async def health(request):
            return web.Response(text='OK', status=200)
        
        app = web.Application()
        app.router.add_get('/health', health)
        
        runner = web.AppRunner(app)
        await runner.setup()
        site = web.TCPSite(runner, '0.0.0.0', 8080)
        await site.start()
        logger.info("Health check server started on port 8080")
    
    def run(self):
        """Main run method"""
        logger.info("Starting ZX Spectrum Emulator Server...")
        
        # Set up signal handlers
        def signal_handler(signum, frame):
            logger.info("Received shutdown signal")
            self.stop_all_processes()
            sys.exit(0)
        
        signal.signal(signal.SIGTERM, signal_handler)
        signal.signal(signal.SIGINT, signal_handler)
        
        # Start all services
        if not self.start_xvfb():
            logger.error("Failed to start Xvfb")
            return
        
        if not self.start_pulseaudio():
            logger.error("Failed to start PulseAudio")
            return
        
        if not self.start_ffmpeg():
            logger.error("Failed to start FFmpeg")
            return
        
        # Start S3 upload thread
        self.start_upload_thread()
        
        # Start servers
        loop = asyncio.get_event_loop()
        
        # Start health check server
        loop.run_until_complete(self.health_check_server())
        
        # Start WebSocket server
        start_server = websockets.serve(self.handle_websocket, '0.0.0.0', 8765)
        loop.run_until_complete(start_server)
        
        logger.info("All services started. Server ready!")
        
        try:
            loop.run_forever()
        except KeyboardInterrupt:
            logger.info("Shutting down...")
        finally:
            self.stop_all_processes()

if __name__ == '__main__':
    server = SpectrumEmulatorServer()
    server.run()
