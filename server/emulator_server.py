#!/usr/bin/env python3
"""
ZX Spectrum Emulator WebSocket Server
Handles communication between web frontend and FUSE emulator
"""

import asyncio
import websockets
import json
import subprocess
import os
import signal
import logging
import time
from pathlib import Path
from typing import Dict, Set, Optional
import psutil
from aiohttp import web, web_runner
import boto3
from botocore.exceptions import ClientError

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SpectrumEmulator:
    def __init__(self):
        self.fuse_process: Optional[subprocess.Popen] = None
        self.ffmpeg_process: Optional[subprocess.Popen] = None
        self.connected_clients: Set[websockets.WebSocketServerProtocol] = set()
        self.emulator_running = False
        self.current_game = None
        
        # Paths
        self.project_root = Path(__file__).parent.parent
        self.games_dir = self.project_root / "games"
        self.stream_dir = self.project_root / "stream"
        self.logs_dir = self.project_root / "logs"
        
        # AWS Configuration
        self.environment = os.getenv('ENVIRONMENT', 'local')
        self.stream_bucket = os.getenv('STREAM_BUCKET')
        self.aws_region = os.getenv('AWS_DEFAULT_REGION', 'us-east-1')
        
        # Initialize S3 client if in AWS environment
        if self.stream_bucket:
            try:
                self.s3_client = boto3.client('s3', region_name=self.aws_region)
                logger.info(f"S3 client initialized for bucket: {self.stream_bucket}")
            except Exception as e:
                logger.error(f"Failed to initialize S3 client: {e}")
                self.s3_client = None
        else:
            self.s3_client = None
        
        # Ensure directories exist
        self.stream_dir.mkdir(exist_ok=True)
        self.logs_dir.mkdir(exist_ok=True)
        
    async def start_emulator(self):
        """Start the FUSE emulator with X11 display"""
        if self.emulator_running:
            logger.info("Emulator already running")
            return True
            
        try:
            # Start FUSE emulator with minimal UI
            cmd = [
                "fuse",
                "--no-sound",  # Disable sound for now
                "--graphics-filter", "none",
                "--machine", "48",  # ZX Spectrum 48K
                "--full-screen", "0",
                "--display", os.getenv('DISPLAY', ':0')
            ]
            
            logger.info(f"Starting FUSE emulator: {' '.join(cmd)}")
            self.fuse_process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=dict(os.environ, DISPLAY=os.getenv('DISPLAY', ':0'))
            )
            
            # Give FUSE time to start
            await asyncio.sleep(2)
            
            if self.fuse_process.poll() is None:
                self.emulator_running = True
                logger.info("FUSE emulator started successfully")
                await self.start_video_stream()
                return True
            else:
                logger.error("FUSE emulator failed to start")
                return False
                
        except Exception as e:
            logger.error(f"Error starting emulator: {e}")
            return False
    
    async def start_video_stream(self):
        """Start FFmpeg video streaming"""
        try:
            # Create HLS streaming directory
            hls_dir = self.stream_dir / "hls"
            hls_dir.mkdir(exist_ok=True)
            
            # FFmpeg command to capture X11 display and create HLS stream
            cmd = [
                "ffmpeg",
                "-f", "x11grab",
                "-video_size", "640x480",
                "-framerate", "25",
                "-i", f"{os.getenv('DISPLAY', ':0')}.0+100,100",
                "-c:v", "libx264",
                "-preset", "ultrafast",
                "-tune", "zerolatency",
                "-crf", "23",
                "-g", "25",
                "-sc_threshold", "0",
                "-f", "hls",
                "-hls_time", "1",
                "-hls_list_size", "3",
                "-hls_flags", "delete_segments",
                "-y",
                str(hls_dir / "stream.m3u8")
            ]
            
            logger.info("Starting video stream")
            self.ffmpeg_process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            
            logger.info("Video streaming started")
            
            # If S3 is configured, start uploading stream segments
            if self.s3_client and self.stream_bucket:
                asyncio.create_task(self.upload_stream_to_s3())
            
        except Exception as e:
            logger.error(f"Error starting video stream: {e}")
    
    async def upload_stream_to_s3(self):
        """Upload HLS stream segments to S3"""
        hls_dir = self.stream_dir / "hls"
        
        while self.emulator_running:
            try:
                # Upload .m3u8 playlist file
                playlist_file = hls_dir / "stream.m3u8"
                if playlist_file.exists():
                    await self.upload_file_to_s3(playlist_file, "hls/stream.m3u8")
                
                # Upload .ts segment files
                for ts_file in hls_dir.glob("*.ts"):
                    s3_key = f"hls/{ts_file.name}"
                    await self.upload_file_to_s3(ts_file, s3_key)
                
                await asyncio.sleep(1)  # Check every second
                
            except Exception as e:
                logger.error(f"Error uploading stream to S3: {e}")
                await asyncio.sleep(5)  # Wait longer on error
    
    async def upload_file_to_s3(self, local_file: Path, s3_key: str):
        """Upload a file to S3"""
        try:
            # Run S3 upload in thread pool to avoid blocking
            loop = asyncio.get_event_loop()
            await loop.run_in_executor(
                None,
                lambda: self.s3_client.upload_file(
                    str(local_file),
                    self.stream_bucket,
                    s3_key,
                    ExtraArgs={
                        'ContentType': 'application/vnd.apple.mpegurl' if s3_key.endswith('.m3u8') else 'video/mp2t',
                        'CacheControl': 'max-age=1'
                    }
                )
            )
        except Exception as e:
            logger.debug(f"Failed to upload {s3_key}: {e}")
    
    async def stop_emulator(self):
        """Stop the emulator and video stream"""
        self.emulator_running = False
        
        # Stop FFmpeg
        if self.ffmpeg_process:
            try:
                self.ffmpeg_process.terminate()
                await asyncio.sleep(1)
                if self.ffmpeg_process.poll() is None:
                    self.ffmpeg_process.kill()
                logger.info("Video stream stopped")
            except Exception as e:
                logger.error(f"Error stopping video stream: {e}")
        
        # Stop FUSE
        if self.fuse_process:
            try:
                self.fuse_process.terminate()
                await asyncio.sleep(1)
                if self.fuse_process.poll() is None:
                    self.fuse_process.kill()
                logger.info("FUSE emulator stopped")
            except Exception as e:
                logger.error(f"Error stopping emulator: {e}")
    
    async def load_game(self, game_file: str):
        """Load a game file into the emulator"""
        game_path = self.games_dir / game_file
        
        if not game_path.exists():
            logger.error(f"Game file not found: {game_path}")
            return False
        
        try:
            # Send file to FUSE via command line (this is a simplified approach)
            # In a real implementation, you'd use FUSE's remote control interface
            logger.info(f"Loading game: {game_file}")
            self.current_game = game_file
            return True
            
        except Exception as e:
            logger.error(f"Error loading game: {e}")
            return False
    
    async def send_key(self, key: str):
        """Send keyboard input to the emulator"""
        try:
            # This would send keys to FUSE
            # For now, we'll just log the key press
            logger.info(f"Key pressed: {key}")
            
            # Broadcast key press to all connected clients
            if self.connected_clients:
                message = {
                    "type": "key_pressed",
                    "key": key,
                    "timestamp": time.time()
                }
                await self.broadcast_message(message)
                
        except Exception as e:
            logger.error(f"Error sending key: {e}")
    
    async def take_screenshot(self):
        """Take a screenshot of the emulator"""
        try:
            screenshot_path = self.stream_dir / f"screenshot_{int(time.time())}.png"
            
            # Use xwd to capture the FUSE window
            cmd = [
                "import",  # ImageMagick's import command
                "-window", "root",
                str(screenshot_path)
            ]
            
            subprocess.run(cmd, check=True)
            logger.info(f"Screenshot saved: {screenshot_path}")
            return str(screenshot_path)
            
        except Exception as e:
            logger.error(f"Error taking screenshot: {e}")
            return None
    
    async def broadcast_message(self, message: dict):
        """Broadcast message to all connected clients"""
        if self.connected_clients:
            message_str = json.dumps(message)
            disconnected = set()
            
            for client in self.connected_clients:
                try:
                    await client.send(message_str)
                except websockets.exceptions.ConnectionClosed:
                    disconnected.add(client)
                except Exception as e:
                    logger.error(f"Error sending message to client: {e}")
                    disconnected.add(client)
            
            # Remove disconnected clients
            self.connected_clients -= disconnected
    
    async def handle_client_message(self, websocket, message_str: str):
        """Handle incoming WebSocket message"""
        try:
            message = json.loads(message_str)
            msg_type = message.get("type")
            
            if msg_type == "start_emulator":
                success = await self.start_emulator()
                await websocket.send(json.dumps({
                    "type": "emulator_status",
                    "running": success,
                    "message": "Emulator started" if success else "Failed to start emulator"
                }))
                
            elif msg_type == "stop_emulator":
                await self.stop_emulator()
                await websocket.send(json.dumps({
                    "type": "emulator_status",
                    "running": False,
                    "message": "Emulator stopped"
                }))
                
            elif msg_type == "load_game":
                game_file = message.get("game")
                success = await self.load_game(game_file)
                await websocket.send(json.dumps({
                    "type": "game_loaded",
                    "success": success,
                    "game": game_file if success else None
                }))
                
            elif msg_type == "key_press":
                key = message.get("key")
                await self.send_key(key)
                
            elif msg_type == "screenshot":
                screenshot_path = await self.take_screenshot()
                await websocket.send(json.dumps({
                    "type": "screenshot_taken",
                    "path": screenshot_path
                }))
                
            elif msg_type == "get_status":
                await websocket.send(json.dumps({
                    "type": "status",
                    "emulator_running": self.emulator_running,
                    "current_game": self.current_game,
                    "connected_clients": len(self.connected_clients)
                }))
                
        except json.JSONDecodeError:
            logger.error("Invalid JSON received")
        except Exception as e:
            logger.error(f"Error handling message: {e}")

# Global emulator instance
emulator = SpectrumEmulator()

async def handle_websocket(websocket, path):
    """Handle WebSocket connections"""
    logger.info(f"New client connected from {websocket.remote_address}")
    emulator.connected_clients.add(websocket)
    
    try:
        # Send initial status
        await websocket.send(json.dumps({
            "type": "connected",
            "message": "Connected to ZX Spectrum Emulator",
            "emulator_running": emulator.emulator_running
        }))
        
        async for message in websocket:
            await emulator.handle_client_message(websocket, message)
            
    except websockets.exceptions.ConnectionClosed:
        logger.info("Client disconnected")
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
    finally:
        emulator.connected_clients.discard(websocket)

async def health_check(request):
    """Health check endpoint for ALB"""
    return web.Response(text="OK", status=200)

async def create_http_server():
    """Create HTTP server for health checks"""
    app = web.Application()
    app.router.add_get('/health', health_check)
    
    runner = web_runner.AppRunner(app)
    await runner.setup()
    
    site = web_runner.TCPSite(runner, '0.0.0.0', 8080)
    await site.start()
    
    logger.info("HTTP server started on port 8080")
    return runner

async def main():
    """Main server function"""
    logger.info("Starting ZX Spectrum Emulator Server")
    logger.info(f"Environment: {emulator.environment}")
    logger.info(f"Stream bucket: {emulator.stream_bucket}")
    
    # Start HTTP server for health checks
    http_runner = await create_http_server()
    
    # Start WebSocket server
    server = await websockets.serve(
        handle_websocket,
        "0.0.0.0",
        8765,
        ping_interval=20,
        ping_timeout=10
    )
    
    logger.info("WebSocket server started on port 8765")
    
    try:
        await server.wait_closed()
    except KeyboardInterrupt:
        logger.info("Shutting down server...")
        await emulator.stop_emulator()
        await http_runner.cleanup()

if __name__ == "__main__":
    asyncio.run(main())
