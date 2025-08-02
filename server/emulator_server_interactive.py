#!/usr/bin/env python3
"""
Enhanced ZX Spectrum Emulator Server with Interactive Keyboard Support
Handles real-time keyboard input and routes it to the FUSE emulator
"""

import asyncio
import websockets
import json
import logging
import subprocess
import os
import signal
import time
import threading
from aiohttp import web, web_runner
import boto3
from botocore.exceptions import ClientError
import tempfile
import shutil

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class InteractiveSpectrumEmulator:
    def __init__(self):
        self.emulator_process = None
        self.ffmpeg_hls_process = None
        self.ffmpeg_youtube_process = None
        self.connected_clients = set()
        self.emulator_running = False
        self.s3_client = None
        self.stream_bucket = os.environ.get('STREAM_BUCKET', 'spectrum-emulator-stream-dev-043309319786')
        self.youtube_key = os.environ.get('YOUTUBE_STREAM_KEY', '')
        
        # Display and capture settings
        self.display = os.environ.get('DISPLAY', ':99')
        self.capture_size = os.environ.get('CAPTURE_SIZE', '256x192')
        self.display_size = os.environ.get('DISPLAY_SIZE', '512x384')
        self.output_resolution = os.environ.get('OUTPUT_RESOLUTION', '1280x720')
        self.capture_offset = os.environ.get('CAPTURE_OFFSET', '0,0')
        self.video_bitrate = os.environ.get('VIDEO_BITRATE', '3000k')
        self.youtube_bitrate = os.environ.get('YOUTUBE_BITRATE', '4000k')
        
        # FUSE emulator control
        self.fuse_fifo_path = '/tmp/fuse_input'
        self.fuse_control_thread = None
        
        self.setup_s3_client()
        self.setup_fuse_control()

    def setup_s3_client(self):
        """Initialize S3 client for HLS streaming"""
        try:
            self.s3_client = boto3.client('s3')
            logger.info(f'S3 client initialized for bucket: {self.stream_bucket}')
        except Exception as e:
            logger.error(f'Failed to initialize S3 client: {e}')

    def setup_fuse_control(self):
        """Setup FIFO pipe for FUSE emulator control"""
        try:
            if os.path.exists(self.fuse_fifo_path):
                os.remove(self.fuse_fifo_path)
            os.mkfifo(self.fuse_fifo_path)
            logger.info(f'FUSE control FIFO created at {self.fuse_fifo_path}')
        except Exception as e:
            logger.error(f'Failed to create FUSE control FIFO: {e}')

    def start_emulator(self):
        """Start the FUSE ZX Spectrum emulator with interactive control"""
        if self.emulator_running:
            logger.info('Emulator already running')
            return True

        try:
            logger.info('Starting FUSE ZX Spectrum emulator with interactive control...')
            
            # FUSE command with SDL output and control options
            fuse_cmd = [
                'fuse-sdl',
                '--display-scale', '2',
                '--full-screen', 'no',
                '--sound', 'yes',
                '--sound-device', 'pulse',
                '--machine', '48',  # ZX Spectrum 48K
                '--speed', '100',   # Normal speed
                '--no-confirm-actions',
                '--graphics-filter', 'none',
                '--stdin',  # Accept input from stdin
                f'--geometry={self.display_size}'
            ]
            
            # Set environment for SDL and audio
            env = os.environ.copy()
            env.update({
                'DISPLAY': self.display,
                'SDL_VIDEODRIVER': 'x11',
                'SDL_AUDIODRIVER': 'pulse',
                'PULSE_RUNTIME_PATH': '/tmp/pulse'
            })
            
            # Start FUSE emulator
            self.emulator_process = subprocess.Popen(
                fuse_cmd,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=env,
                preexec_fn=os.setsid
            )
            
            # Give emulator time to start
            time.sleep(3)
            
            if self.emulator_process.poll() is None:
                self.emulator_running = True
                logger.info('FUSE emulator started successfully')
                
                # Start video streaming
                self.start_video_streaming()
                
                # Start control thread
                self.start_control_thread()
                
                return True
            else:
                logger.error('FUSE emulator failed to start')
                return False
                
        except Exception as e:
            logger.error(f'Failed to start emulator: {e}')
            return False

    def start_control_thread(self):
        """Start thread to handle emulator control"""
        if self.fuse_control_thread and self.fuse_control_thread.is_alive():
            return
            
        self.fuse_control_thread = threading.Thread(target=self.control_loop, daemon=True)
        self.fuse_control_thread.start()
        logger.info('FUSE control thread started')

    def control_loop(self):
        """Main control loop for handling emulator input"""
        logger.info('FUSE control loop started')
        # This thread can be used for additional emulator monitoring
        while self.emulator_running and self.emulator_process:
            try:
                time.sleep(0.1)
                if self.emulator_process.poll() is not None:
                    logger.warning('Emulator process has terminated')
                    self.emulator_running = False
                    break
            except Exception as e:
                logger.error(f'Error in control loop: {e}')
                break

    def send_key_to_emulator(self, key, action='press'):
        """Send keyboard input to FUSE emulator"""
        if not self.emulator_running or not self.emulator_process:
            return False
            
        try:
            # Map web keys to FUSE key codes
            key_mapping = {
                # Numbers
                '1': '1', '2': '2', '3': '3', '4': '4', '5': '5',
                '6': '6', '7': '7', '8': '8', '9': '9', '0': '0',
                
                # Letters
                'Q': 'q', 'W': 'w', 'E': 'e', 'R': 'r', 'T': 't',
                'Y': 'y', 'U': 'u', 'I': 'i', 'O': 'o', 'P': 'p',
                'A': 'a', 'S': 's', 'D': 'd', 'F': 'f', 'G': 'g',
                'H': 'h', 'J': 'j', 'K': 'k', 'L': 'l',
                'Z': 'z', 'X': 'x', 'C': 'c', 'V': 'v', 'B': 'b',
                'N': 'n', 'M': 'm',
                
                # Special keys
                'SPACE': ' ',
                'ENTER': '\n',
                'SHIFT': 'shift',
                'SYMBOL': 'ctrl',
                'DELETE': '\b',
            }
            
            fuse_key = key_mapping.get(key, key.lower())
            
            if action == 'press':
                # Send key press to emulator stdin
                if self.emulator_process.stdin:
                    self.emulator_process.stdin.write(fuse_key.encode())
                    self.emulator_process.stdin.flush()
                    logger.info(f'Sent key to emulator: {key} -> {fuse_key}')
                    return True
            
            # Note: FUSE doesn't have explicit key release events via stdin
            # Key releases are handled automatically
            
        except Exception as e:
            logger.error(f'Failed to send key to emulator: {e}')
            return False
            
        return True

    def start_video_streaming(self):
        """Start FFmpeg video streaming for both HLS and YouTube"""
        try:
            # Stop any existing streams
            self.stop_video_streaming()
            
            # Create output directory
            os.makedirs('/tmp/stream', exist_ok=True)
            
            # HLS streaming command
            hls_cmd = [
                'ffmpeg',
                '-f', 'x11grab',
                '-video_size', self.capture_size,
                '-framerate', '25',
                '-i', f'{self.display}+{self.capture_offset}',
                '-f', 'pulse',
                '-i', 'default',
                '-c:v', 'libx264',
                '-preset', 'ultrafast',
                '-tune', 'zerolatency',
                '-crf', '23',
                '-maxrate', self.video_bitrate,
                '-bufsize', f'{int(self.video_bitrate[:-1]) * 2}k',
                '-vf', f'scale={self.output_resolution}:flags=neighbor',
                '-c:a', 'aac',
                '-b:a', '128k',
                '-f', 'hls',
                '-hls_time', '2',
                '-hls_list_size', '5',
                '-hls_flags', 'delete_segments',
                '/tmp/stream/stream.m3u8'
            ]
            
            self.ffmpeg_hls_process = subprocess.Popen(
                hls_cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                preexec_fn=os.setsid
            )
            
            # YouTube streaming command (if key provided)
            if self.youtube_key:
                youtube_cmd = [
                    'ffmpeg',
                    '-f', 'x11grab',
                    '-video_size', self.capture_size,
                    '-framerate', '25',
                    '-i', f'{self.display}+{self.capture_offset}',
                    '-f', 'pulse',
                    '-i', 'default',
                    '-c:v', 'libx264',
                    '-preset', 'fast',
                    '-tune', 'zerolatency',
                    '-crf', '20',
                    '-maxrate', self.youtube_bitrate,
                    '-bufsize', f'{int(self.youtube_bitrate[:-1]) * 2}k',
                    '-vf', f'scale=1920x1080:flags=lanczos',
                    '-c:a', 'aac',
                    '-b:a', '128k',
                    '-f', 'flv',
                    f'rtmp://a.rtmp.youtube.com/live2/{self.youtube_key}'
                ]
                
                self.ffmpeg_youtube_process = subprocess.Popen(
                    youtube_cmd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    preexec_fn=os.setsid
                )
                logger.info('YouTube streaming started')
            
            # Start S3 upload thread
            self.start_s3_upload_thread()
            
            logger.info('Video streaming started successfully')
            return True
            
        except Exception as e:
            logger.error(f'Failed to start video streaming: {e}')
            return False

    def start_s3_upload_thread(self):
        """Start thread to upload HLS segments to S3"""
        def upload_loop():
            while self.emulator_running:
                try:
                    # Upload HLS files to S3
                    hls_dir = '/tmp/stream'
                    if os.path.exists(hls_dir):
                        for file in os.listdir(hls_dir):
                            if file.endswith(('.m3u8', '.ts')):
                                local_path = os.path.join(hls_dir, file)
                                s3_key = f'hls/{file}'
                                
                                try:
                                    self.s3_client.upload_file(
                                        local_path, 
                                        self.stream_bucket, 
                                        s3_key,
                                        ExtraArgs={'ContentType': 'application/x-mpegURL' if file.endswith('.m3u8') else 'video/MP2T'}
                                    )
                                except Exception as e:
                                    logger.error(f'Failed to upload {file}: {e}')
                    
                    time.sleep(1)
                    
                except Exception as e:
                    logger.error(f'Error in S3 upload loop: {e}')
                    time.sleep(5)
        
        if self.s3_client:
            upload_thread = threading.Thread(target=upload_loop, daemon=True)
            upload_thread.start()
            logger.info('S3 upload thread started')

    def stop_emulator(self):
        """Stop the emulator and all related processes"""
        logger.info('Stopping emulator and streaming...')
        
        self.emulator_running = False
        
        # Stop video streaming
        self.stop_video_streaming()
        
        # Stop emulator
        if self.emulator_process:
            try:
                os.killpg(os.getpgid(self.emulator_process.pid), signal.SIGTERM)
                self.emulator_process.wait(timeout=5)
            except:
                try:
                    os.killpg(os.getpgid(self.emulator_process.pid), signal.SIGKILL)
                except:
                    pass
            self.emulator_process = None
        
        logger.info('Emulator stopped')
        return True

    def stop_video_streaming(self):
        """Stop FFmpeg streaming processes"""
        for process in [self.ffmpeg_hls_process, self.ffmpeg_youtube_process]:
            if process:
                try:
                    os.killpg(os.getpgid(process.pid), signal.SIGTERM)
                    process.wait(timeout=5)
                except:
                    try:
                        os.killpg(os.getpgid(process.pid), signal.SIGKILL)
                    except:
                        pass
        
        self.ffmpeg_hls_process = None
        self.ffmpeg_youtube_process = None

    async def handle_websocket(self, websocket):
        """Handle WebSocket connections"""
        self.connected_clients.add(websocket)
        logger.info(f'WebSocket client connected. Total clients: {len(self.connected_clients)}')
        
        # Send initial status
        await websocket.send(json.dumps({
            'type': 'connected',
            'message': 'Interactive ZX Spectrum Emulator Server',
            'emulator_running': self.emulator_running,
            'output_resolution': self.output_resolution,
            'video_bitrate': self.video_bitrate,
            'features': ['interactive_keyboard', 'real_time_input', 'dual_streaming']
        }))
        
        try:
            async for message in websocket:
                try:
                    data = json.loads(message)
                    await self.handle_message(websocket, data)
                except json.JSONDecodeError:
                    logger.error(f'Invalid JSON received: {message}')
                except Exception as e:
                    logger.error(f'Error handling message: {e}')
                    
        except websockets.exceptions.ConnectionClosed:
            logger.info('WebSocket client disconnected')
        finally:
            self.connected_clients.discard(websocket)

    async def handle_message(self, websocket, data):
        """Handle incoming WebSocket messages"""
        message_type = data.get('type')
        
        if message_type == 'start_emulator':
            success = self.start_emulator()
            await websocket.send(json.dumps({
                'type': 'emulator_status',
                'running': success,
                'message': 'Emulator started successfully' if success else 'Failed to start emulator'
            }))
            
        elif message_type == 'stop_emulator':
            success = self.stop_emulator()
            await websocket.send(json.dumps({
                'type': 'emulator_status',
                'running': False,
                'message': 'Emulator stopped' if success else 'Failed to stop emulator'
            }))
            
        elif message_type == 'status':
            await websocket.send(json.dumps({
                'type': 'emulator_status',
                'running': self.emulator_running,
                'message': 'Status check',
                'output_resolution': self.output_resolution,
                'connected_clients': len(self.connected_clients)
            }))
            
        elif message_type == 'key_input':
            key = data.get('key')
            action = data.get('action', 'press')
            
            if key:
                success = self.send_key_to_emulator(key, action)
                await websocket.send(json.dumps({
                    'type': 'key_response',
                    'key': key,
                    'action': action,
                    'success': success,
                    'error': None if success else 'Failed to send key to emulator'
                }))
                logger.info(f'Key {action}: {key} - {"Success" if success else "Failed"}')
            
        elif message_type == 'reset':
            if self.emulator_running:
                # Send reset command to emulator
                success = self.send_key_to_emulator('RESET', 'command')
                await websocket.send(json.dumps({
                    'type': 'emulator_status',
                    'running': self.emulator_running,
                    'message': 'Emulator reset' if success else 'Reset failed'
                }))
            
        elif message_type == 'command':
            command = data.get('command', '')
            if command and self.emulator_running:
                # Send command string to emulator
                for char in command:
                    self.send_key_to_emulator(char, 'press')
                    time.sleep(0.05)  # Small delay between characters
                
                await websocket.send(json.dumps({
                    'type': 'command_response',
                    'command': command,
                    'success': True,
                    'message': f'Command sent: {command}'
                }))

    async def health_check(self, request):
        """Health check endpoint"""
        return web.Response(
            text=f'OK - Interactive Emulator Server - Resolution: {self.output_resolution} - Running: {self.emulator_running}', 
            status=200
        )

    async def start_server(self):
        """Start the WebSocket and HTTP servers"""
        # Start WebSocket server
        websocket_server = websockets.serve(
            self.handle_websocket, 
            '0.0.0.0', 
            8765,
            ping_interval=30,
            ping_timeout=10
        )
        
        # Start HTTP server for health checks
        app = web.Application()
        app.router.add_get('/health', self.health_check)
        
        runner = web_runner.AppRunner(app)
        await runner.setup()
        site = web_runner.TCPSite(runner, '0.0.0.0', 8080)
        await site.start()
        
        logger.info('Interactive ZX Spectrum Emulator Server started')
        logger.info('WebSocket server: ws://0.0.0.0:8765')
        logger.info('Health check: http://0.0.0.0:8080/health')
        logger.info(f'Output resolution: {self.output_resolution}')
        logger.info(f'Video bitrate: {self.video_bitrate}')
        logger.info(f'YouTube streaming: {"Enabled" if self.youtube_key else "Disabled"}')
        
        # Start WebSocket server
        await websocket_server
        
        # Keep the server running
        try:
            await asyncio.Future()  # Run forever
        except KeyboardInterrupt:
            logger.info('Server shutdown requested')
        finally:
            self.stop_emulator()

def main():
    """Main entry point"""
    logger.info('Starting Interactive ZX Spectrum Emulator Server...')
    
    emulator = InteractiveSpectrumEmulator()
    
    try:
        asyncio.run(emulator.start_server())
    except KeyboardInterrupt:
        logger.info('Server stopped by user')
    except Exception as e:
        logger.error(f'Server error: {e}')
    finally:
        emulator.stop_emulator()

if __name__ == '__main__':
    main()
