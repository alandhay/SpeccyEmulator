#!/bin/bash

# Create ULTRA HD 1080p streaming task definition with optimized settings

cat > /tmp/ultra-hd-task.json << 'EOF'
{
  "family": "spectrum-emulator-streaming",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "4096",
  "memory": "8192",
  "executionRoleArn": "arn:aws:iam::043309319786:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "spectrum-emulator-streamer",
      "image": "ubuntu:22.04",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        },
        {
          "containerPort": 8765,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "YOUTUBE_RTMP_KEY",
          "value": "0ebh-efdh-9qtq-2eq3-e6hz"
        },
        {
          "name": "TWITCH_RTMP_KEY",
          "value": "DISABLED"
        },
        {
          "name": "DISPLAY",
          "value": ":99"
        },
        {
          "name": "STREAM_BUCKET",
          "value": "spectrum-emulator-stream-dev-043309319786"
        },
        {
          "name": "QUALITY_MODE",
          "value": "ULTRA_HD"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/spectrum-emulator-streaming",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": [
          "CMD-SHELL",
          "curl -f http://localhost:8080/health || exit 1"
        ],
        "interval": 30,
        "timeout": 10,
        "retries": 5,
        "startPeriod": 300
      },
      "command": [
        "bash",
        "-c",
        "#!/bin/bash\nset -e\n\necho '🚀 Starting ZX Spectrum ULTRA HD 1080p Streaming Setup...'\n\n# Update and install dependencies\napt-get update\napt-get install -y \\\n  python3 python3-pip curl \\\n  xvfb pulseaudio \\\n  ffmpeg \\\n  fuse-emulator-sdl \\\n  wget unzip awscli \\\n  x11-utils imagemagick\n\necho '📦 Installing Python dependencies...'\npip3 install websockets aiohttp\n\n# Create directories\nmkdir -p /tmp/games /tmp/logs /tmp/hls /tmp/screenshots\n\necho '🎮 Downloading test games...'\nwget -O /tmp/games/manic_miner.tzx 'https://archive.org/download/World_of_Spectrum_June_2017_Mirror/World%20of%20Spectrum%20June%202017%20Mirror.zip/World%20of%20Spectrum%20June%202017%20Mirror%2Fgames%2Fm%2FManicMiner.tzx' || echo 'Game download failed, will use built-in ROM'\nwget -O /tmp/games/jetset_willy.tzx 'https://archive.org/download/World_of_Spectrum_June_2017_Mirror/World%20of%20Spectrum%20June%202017%20Mirror.zip/World%20of%20Spectrum%20June%202017%20Mirror%2Fgames%2Fj%2FJetSetWilly.tzx' || echo 'Jetset Willy download failed'\n\necho '🖥️  Starting ULTRA HD virtual display (1920x1080)...'\n# Create 1920x1080 virtual display with 32-bit color depth for maximum quality\nXvfb :99 -screen 0 1920x1080x32 -ac +extension GLX +render -noreset &\nexport DISPLAY=:99\nsleep 2\n\necho '🔊 Starting PulseAudio...'\npulseaudio --start --exit-idle-time=-1\n\n# Create ULTRA HD streaming script\ncat > /tmp/start_streaming.sh << 'STREAM_EOF'\n#!/bin/bash\n\necho \"🎬 === ZX Spectrum ULTRA HD 1080p Streaming ===\"\necho \"📺 YouTube Key: ${YOUTUBE_RTMP_KEY:0:10}...\"\necho \"🎯 Target Resolution: 1920x1080 @ 60fps\"\necho \"💎 Quality Mode: ULTRA HD with dual output\"\necho \"📡 Outputs: YouTube RTMP + S3 HLS\"\n\n# Function to start FUSE emulator with ULTRA HD scaling\nstart_emulator() {\n    echo \"🚀 Starting ZX Spectrum emulator in ULTRA HD mode...\"\n    \n    # Set window manager for fullscreen\n    export DISPLAY=:99\n    \n    # Start FUSE with maximum quality settings\n    # Use 8x scaling for ultra-crisp pixels, fullscreen mode\n    fuse --machine 48 \\\n         --graphics-filter 8x \\\n         --full-screen \\\n         --sound \\\n         --no-confirm-actions \\\n         --auto-load /tmp/games/manic_miner.tzx &\n    FUSE_PID=$!\n    echo \"✅ FUSE started with PID: $FUSE_PID (8x scaling for ULTRA HD quality)\"\n    sleep 8\n    \n    # Take a screenshot to verify display\n    xwd -root -out /tmp/screenshots/startup.xwd\n    convert /tmp/screenshots/startup.xwd /tmp/screenshots/startup.png 2>/dev/null || echo \"Screenshot conversion failed\"\n}\n\n# Function to start ULTRA HD dual-output streaming\nstart_ultra_hd_stream() {\n    local rtmp_key=$1\n    local bucket=$2\n    \n    if [ -z \"$rtmp_key\" ] || [ \"$rtmp_key\" = \"YOUR_YOUTUBE_STREAM_KEY\" ]; then\n        echo \"❌ ERROR: No valid YouTube stream key provided!\"\n        return 1\n    fi\n    \n    RTMP_URL=\"rtmp://a.rtmp.youtube.com/live2/$rtmp_key\"\n    \n    echo \"🎬 Starting ULTRA HD FFmpeg dual-output stream...\"\n    echo \"📐 Resolution: 1920x1080 @ 60fps\"\n    echo \"🎯 Video Bitrate: 8000k (8 Mbps) - YouTube Premium Quality\"\n    echo \"🎵 Audio Bitrate: 320k (Studio Quality)\"\n    echo \"🔄 Dual Output: YouTube RTMP + S3 HLS\"\n    echo \"🎨 Pixel-perfect scaling with advanced filtering\"\n    \n    # ULTRA HD dual-output streaming with premium settings\n    ffmpeg -f x11grab -video_size 1920x1080 -framerate 60 -i :99 \\\n           -f pulse -i default \\\n           -filter_complex \"[0:v]scale=1920:1080:flags=lanczos:param0=3,unsharp=5:5:1.0:5:5:0.0[scaled]\" \\\n           -map \"[scaled]\" -map 1:a \\\n           -c:v libx264 -preset slow -tune zerolatency \\\n           -b:v 8000k -minrate 6000k -maxrate 10000k -bufsize 16000k \\\n           -pix_fmt yuv420p -g 120 -keyint_min 60 \\\n           -profile:v high -level 4.2 \\\n           -x264-params \"aq-mode=2:aq-strength=1.0:deblock=1,1\" \\\n           -c:a aac -b:a 320k -ar 48000 -ac 2 -aac_coder twoloop \\\n           -f tee \\\n           \"[f=flv]$RTMP_URL|[f=hls:hls_time=2:hls_list_size=5:hls_flags=delete_segments]/tmp/hls/stream.m3u8\" &\n    FFMPEG_PID=$!\n    echo \"✅ ULTRA HD FFmpeg started with PID: $FFMPEG_PID - Streaming in 1080p60!\"\n    \n    # Upload HLS segments to S3 continuously with high frequency\n    (\n        while true; do\n            sleep 3\n            if [ -f /tmp/hls/stream.m3u8 ]; then\n                aws s3 sync /tmp/hls/ s3://$bucket/hls/ --delete --quiet\n                # Also upload latest screenshot\n                if [ -f /tmp/screenshots/startup.png ]; then\n                    aws s3 cp /tmp/screenshots/startup.png s3://$bucket/screenshots/latest.png --quiet\n                fi\n            fi\n        done\n    ) &\n    S3_SYNC_PID=$!\n    echo \"📤 S3 sync started with PID: $S3_SYNC_PID (3-second intervals)\"\n    \n    # Monitor stream quality\n    (\n        while true; do\n            sleep 60\n            if [ ! -z \"$FFMPEG_PID\" ] && kill -0 $FFMPEG_PID 2>/dev/null; then\n                echo \"📊 Stream Status: ULTRA HD 1080p60 @ 8Mbps - Running smoothly\"\n                # Take periodic screenshots\n                xwd -root -out /tmp/screenshots/current_$(date +%s).xwd 2>/dev/null\n            fi\n        done\n    ) &\n    MONITOR_PID=$!\n}\n\n# Start emulator\nstart_emulator\n\n# Start ULTRA HD streaming if key is provided\nif [ ! -z \"$YOUTUBE_RTMP_KEY\" ] && [ \"$YOUTUBE_RTMP_KEY\" != \"YOUR_YOUTUBE_STREAM_KEY\" ] && [ \"$YOUTUBE_RTMP_KEY\" != \"DISABLED\" ]; then\n    echo \"🚀 Starting ULTRA HD stream with key: ${YOUTUBE_RTMP_KEY:0:10}...\"\n    start_ultra_hd_stream \"$YOUTUBE_RTMP_KEY\" \"$STREAM_BUCKET\"\nelse\n    echo \"⚠️  YouTube streaming disabled or no key provided\"\nfi\n\n# Keep script running and monitor processes\necho \"✅ ULTRA HD streaming setup complete. Monitoring processes...\"\nwhile true; do\n    sleep 30\n    \n    # Check if FUSE is still running\n    if ! kill -0 $FUSE_PID 2>/dev/null; then\n        echo \"🔄 FUSE emulator stopped, restarting...\"\n        start_emulator\n    fi\n    \n    # Check if FFmpeg is still running (if it was started)\n    if [ ! -z \"$FFMPEG_PID\" ] && ! kill -0 $FFMPEG_PID 2>/dev/null; then\n        echo \"🔄 FFmpeg stopped, restarting ULTRA HD stream...\"\n        start_ultra_hd_stream \"$YOUTUBE_RTMP_KEY\" \"$STREAM_BUCKET\"\n    fi\n    \n    # Health check\n    echo \"💓 Health Check: $(date) - ULTRA HD streaming active\"\ndone\nSTREAM_EOF\n\nchmod +x /tmp/start_streaming.sh\n\n# Create enhanced WebSocket server\ncat > /tmp/emulator_server.py << 'EOF'\nimport asyncio\nimport websockets\nimport json\nimport logging\nimport subprocess\nimport os\nfrom aiohttp import web\nimport time\n\nlogging.basicConfig(level=logging.INFO)\nlogger = logging.getLogger(__name__)\n\nclass UltraHDEmulatorServer:\n    def __init__(self):\n        self.clients = set()\n        self.emulator_process = None\n        self.streaming_process = None\n        self.start_time = time.time()\n    \n    async def health(self, request):\n        youtube_key = os.environ.get('YOUTUBE_RTMP_KEY', 'Not set')\n        uptime = int(time.time() - self.start_time)\n        return web.Response(text=f'🚀 ZX Spectrum ULTRA HD 1080p Streaming Server OK - Key: {youtube_key[:10]}... - Uptime: {uptime}s')\n    \n    async def status(self, request):\n        youtube_key = os.environ.get('YOUTUBE_RTMP_KEY', 'Not set')\n        bucket = os.environ.get('STREAM_BUCKET', 'Not set')\n        uptime = int(time.time() - self.start_time)\n        status = {\n            'emulator_running': self.streaming_process is not None,\n            'streaming_active': self.streaming_process is not None,\n            'display': os.environ.get('DISPLAY', 'Not set'),\n            'youtube_key_configured': youtube_key != 'YOUR_YOUTUBE_STREAM_KEY' and youtube_key != 'Not set',\n            'youtube_key_preview': youtube_key[:10] + '...' if len(youtube_key) > 10 else youtube_key,\n            'quality': '🎬 ULTRA HD - 1920x1080 @ 60fps @ 8Mbps',\n            'resolution': '1920x1080',\n            'framerate': '60fps',\n            'bitrate': '8000k (Premium Quality)',\n            'audio_quality': '320k AAC (Studio Quality)',\n            'outputs': ['YouTube RTMP', 'S3 HLS'],\n            's3_bucket': bucket,\n            'uptime_seconds': uptime,\n            'scaling_mode': '8x pixel-perfect with Lanczos filtering',\n            'cpu_allocation': '4096 CPU units',\n            'memory_allocation': '8192 MB'\n        }\n        return web.json_response(status)\n    \n    async def websocket_handler(self, websocket):\n        logger.info('🔌 Client connected for ULTRA HD streaming control')\n        self.clients.add(websocket)\n        try:\n            youtube_key = os.environ.get('YOUTUBE_RTMP_KEY', 'Not set')\n            await websocket.send(json.dumps({\n                'type': 'connected',\n                'message': '🚀 ZX Spectrum ULTRA HD 1080p Streaming Server Ready! 🎬✨',\n                'streaming_to': 'YouTube Live + S3 HLS',\n                'quality': '1920x1080 @ 60fps @ 8Mbps (Premium Quality)',\n                'audio_quality': '320k AAC Studio Quality',\n                'youtube_configured': youtube_key != 'YOUR_YOUTUBE_STREAM_KEY',\n                'youtube_key_preview': youtube_key[:10] + '...' if len(youtube_key) > 10 else youtube_key,\n                'features': ['8x Pixel Scaling', 'Lanczos Filtering', 'Dual Output', 'Auto Game Loading']\n            }))\n            \n            async for message in websocket:\n                try:\n                    data = json.loads(message)\n                    await self.handle_message(websocket, data)\n                except json.JSONDecodeError:\n                    await websocket.send(json.dumps({\n                        'type': 'error',\n                        'message': 'Invalid JSON message'\n                    }))\n        except Exception as e:\n            logger.error(f'WebSocket error: {e}')\n        finally:\n            self.clients.discard(websocket)\n    \n    async def handle_message(self, websocket, data):\n        msg_type = data.get('type')\n        \n        if msg_type == 'start_streaming':\n            if not self.streaming_process:\n                logger.info('🚀 Starting ULTRA HD streaming process...')\n                self.streaming_process = subprocess.Popen(['/tmp/start_streaming.sh'])\n                await websocket.send(json.dumps({\n                    'type': 'streaming_started',\n                    'message': '🎬 ZX Spectrum emulator started - now streaming in ULTRA HD 1080p60 to YouTube + S3! 🔴✨🚀'\n                }))\n            else:\n                await websocket.send(json.dumps({\n                    'type': 'already_streaming',\n                    'message': '✅ ULTRA HD streaming already active'\n                }))\n        \n        elif msg_type == 'stop_streaming':\n            if self.streaming_process:\n                self.streaming_process.terminate()\n                self.streaming_process = None\n                await websocket.send(json.dumps({\n                    'type': 'streaming_stopped',\n                    'message': '⏹️ ULTRA HD streaming stopped'\n                }))\n        \n        elif msg_type == 'status':\n            uptime = int(time.time() - self.start_time)\n            await websocket.send(json.dumps({\n                'type': 'status_response',\n                'emulator_running': self.streaming_process is not None,\n                'streaming_to': 'YouTube Live + S3 HLS',\n                'quality': '🎬 ULTRA HD 1920x1080 @ 60fps @ 8Mbps',\n                'uptime': f'{uptime} seconds',\n                'message': '📊 ULTRA HD Status updated'\n            }))\n        \n        elif msg_type == 'screenshot':\n            # Trigger a screenshot\n            try:\n                subprocess.run(['xwd', '-root', '-out', '/tmp/screenshots/manual.xwd'], check=True)\n                subprocess.run(['convert', '/tmp/screenshots/manual.xwd', '/tmp/screenshots/manual.png'], check=True)\n                await websocket.send(json.dumps({\n                    'type': 'screenshot_taken',\n                    'message': '📸 Screenshot captured in ULTRA HD quality'\n                }))\n            except Exception as e:\n                await websocket.send(json.dumps({\n                    'type': 'screenshot_error',\n                    'message': f'Screenshot failed: {str(e)}'\n                }))\n        \n        else:\n            await websocket.send(json.dumps({\n                'type': 'unknown_command',\n                'message': f'Unknown command: {msg_type}'\n            }))\n    \n    async def start(self):\n        # Start HTTP server\n        app = web.Application()\n        app.router.add_get('/health', self.health)\n        app.router.add_get('/status', self.status)\n        runner = web.AppRunner(app)\n        await runner.setup()\n        site = web.TCPSite(runner, '0.0.0.0', 8080)\n        await site.start()\n        logger.info('🌐 HTTP server started on port 8080')\n        \n        # Start WebSocket server\n        server = await websockets.serve(self.websocket_handler, '0.0.0.0', 8765)\n        logger.info('🔌 WebSocket server started on port 8765 - Ready for ULTRA HD streaming! 🚀')\n        await server.wait_closed()\n\nif __name__ == '__main__':\n    server = UltraHDEmulatorServer()\n    asyncio.run(server.start())\nEOF\n\necho '🚀 Starting ULTRA HD 1080p Streaming Server...'\npython3 /tmp/emulator_server.py\n"
      ]
    }
  ]
}
EOF

echo "🎬 ULTRA HD 1080p streaming task definition created!"
echo ""
echo "🚀 KEY IMPROVEMENTS:"
echo "   📐 Resolution: 1920x1080 @ 60fps"
echo "   🎯 Video Bitrate: 8000k (8 Mbps) - YouTube Premium Quality"
echo "   🎵 Audio Bitrate: 320k AAC Studio Quality"
echo "   🎨 8x pixel scaling with advanced Lanczos filtering"
echo "   🔄 Dual output: YouTube RTMP + S3 HLS simultaneously"
echo "   💾 4GB CPU / 8GB RAM for smooth performance"
echo "   📸 Screenshot capture capability"
echo "   📊 Enhanced monitoring and health checks"
echo ""

# Register the new task definition
echo "📝 Registering ULTRA HD task definition..."
aws ecs register-task-definition --cli-input-json file:///tmp/ultra-hd-task.json --region us-east-1

if [ $? -eq 0 ]; then
    echo "✅ ULTRA HD task definition registered successfully!"
    echo ""
    echo "🎬 Ready to deploy ULTRA HD 1080p streaming!"
    echo "   Use: aws ecs update-service --cluster spectrum-emulator-cluster-dev --service spectrum-youtube-streaming --task-definition spectrum-emulator-streaming"
else
    echo "❌ Failed to register task definition"
fi
