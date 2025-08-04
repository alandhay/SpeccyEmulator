# Core Key Injection Fix - Apply Proven Method to Production

## 🎯 **OBJECTIVE**

Fix the remote control problem by implementing the **exact proven key injection method** from local tests into the production server. No screenshot features needed - the livestream provides visual feedback.

## ✅ **PROVEN METHOD SUMMARY**

Our local tests definitively proved this method works:

```bash
# PROVEN COMMAND PATTERN
xdotool search --name "Fuse" windowfocus key ${x11_key}
```

**Evidence**: Screenshots show `screenshots_different: true` - keys actually reach the emulator.

## 🔧 **CURRENT PROBLEM**

Your production server has WebSocket error 1011 and keys don't reach the FUSE emulator. The issue is in the server implementation, not the core technology.

## 🚀 **IMPLEMENTATION PLAN**

### **Step 1: Update Key Injection Method**

**File**: `server/emulator_server_fixed_v5.py`

**REPLACE** the current `send_key_to_emulator` method with the **exact proven pattern**:

```python
def send_key_to_emulator(self, key):
    """Send key press to FUSE emulator using PROVEN xdotool method"""
    try:
        if not self.emulator_running:
            logger.warning(f"Emulator not running, ignoring key: {key}")
            return False, "Emulator not running"
            
        # Map the key to X11 key name (same as local test)
        x11_key = self.key_mapping.get(key, key.lower())
        
        # Use EXACT command pattern from successful local test
        result = subprocess.run([
            'xdotool', 
            'search', '--name', 'Fuse',
            'windowfocus',
            'key', x11_key
        ], env={'DISPLAY': ':99'}, capture_output=True, text=True, timeout=5)
        
        if result.returncode == 0:
            logger.info(f"✅ Successfully sent key '{key}' (mapped to '{x11_key}') to FUSE emulator")
            return True, f"Key '{key}' sent successfully"
        else:
            logger.error(f"❌ Failed to send key '{key}': {result.stderr}")
            return False, f"xdotool error: {result.stderr.strip()}"
            
    except subprocess.TimeoutExpired:
        logger.error(f"❌ Timeout sending key '{key}'")
        return False, "xdotool timeout"
    except Exception as e:
        logger.error(f"❌ Exception sending key '{key}' to emulator: {e}")
        return False, f"Exception: {str(e)}"
```

### **Step 2: Add Window Validation**

**ADD** this validation function to ensure FUSE window is accessible:

```python
def validate_fuse_window(self):
    """Validate FUSE window exists and is accessible - from proven method"""
    try:
        result = subprocess.run([
            'xdotool', 'search', '--name', 'Fuse'
        ], env={'DISPLAY': ':99'}, capture_output=True, text=True, timeout=5)
        
        if result.returncode == 0 and result.stdout.strip():
            window_id = result.stdout.strip().split('\n')[0]
            logger.info(f"✅ FUSE window found: {window_id}")
            return True, window_id
        else:
            logger.error("❌ FUSE window not found")
            return False, None
            
    except subprocess.TimeoutExpired:
        logger.error("❌ Timeout finding FUSE window")
        return False, None
    except Exception as e:
        logger.error(f"❌ Error finding FUSE window: {e}")
        return False, None
```

### **Step 3: Fix WebSocket Message Handling**

**REPLACE** the WebSocket message handler to eliminate error 1011:

```python
async def handle_message(self, websocket, data):
    """Handle WebSocket messages with proven error handling"""
    try:
        message_type = data.get('type')
        logger.info(f"Received message type: {message_type}")
        
        if message_type == 'key_press':
            key = data.get('key', '').upper()
            
            if not key:
                await websocket.send(json.dumps({
                    "type": "error",
                    "message": "No key specified"
                }))
                return
            
            # Use proven key injection method
            success, message = self.send_key_to_emulator(key)
            
            # Send response
            response = {
                "type": "key_response",
                "key": key,
                "success": success,
                "message": message,
                "timestamp": time.time()
            }
            
            await websocket.send(json.dumps(response))
            
        elif message_type == 'mouse_click':
            # Apply same proven pattern for mouse if needed
            x = data.get('x', 0)
            y = data.get('y', 0)
            button = data.get('button', 'left')
            
            success, message = self.send_mouse_click_to_emulator(button, x, y)
            
            response = {
                "type": "mouse_response",
                "success": success,
                "message": message,
                "timestamp": time.time()
            }
            
            await websocket.send(json.dumps(response))
            
        elif message_type == 'ping':
            await websocket.send(json.dumps({
                "type": "pong",
                "timestamp": time.time()
            }))
            
        elif message_type == 'status':
            window_valid, window_id = self.validate_fuse_window()
            await websocket.send(json.dumps({
                "type": "status_response",
                "emulator_running": self.emulator_running,
                "fuse_window_valid": window_valid,
                "fuse_window_id": window_id,
                "timestamp": time.time()
            }))
            
        else:
            await websocket.send(json.dumps({
                "type": "error",
                "message": f"Unknown message type: {message_type}"
            }))
            
    except Exception as e:
        logger.error(f"Error handling message: {e}")
        try:
            await websocket.send(json.dumps({
                "type": "error",
                "message": str(e)
            }))
        except:
            logger.error("Failed to send error response")
```

### **Step 4: Add Mouse Support (Same Proven Pattern)**

**ADD** mouse support using the same proven xdotool approach:

```python
def send_mouse_click_to_emulator(self, button, x=None, y=None):
    """Send mouse click to FUSE emulator using proven xdotool method"""
    try:
        if not self.emulator_running:
            logger.warning(f"Emulator not running, ignoring mouse click")
            return False, "Emulator not running"
        
        # Find and focus FUSE window (same as proven key method)
        window_valid, window_id = self.validate_fuse_window()
        if not window_valid:
            return False, "FUSE window not found"
        
        # Build xdotool command
        cmd = ['xdotool', 'windowfocus', window_id]
        
        # Add coordinates if provided
        if x is not None and y is not None:
            # Map browser coordinates to emulator coordinates if needed
            cmd.extend(['mousemove', str(x), str(y)])
        
        # Add click
        if button == 'right':
            cmd.extend(['click', '3'])
        else:
            cmd.extend(['click', '1'])
        
        result = subprocess.run(cmd, env={'DISPLAY': ':99'}, 
                              capture_output=True, text=True, timeout=5)
        
        if result.returncode == 0:
            logger.info(f"✅ Successfully sent mouse {button} click to FUSE emulator")
            return True, f"Mouse {button} click sent successfully"
        else:
            logger.error(f"❌ Failed to send mouse click: {result.stderr}")
            return False, f"xdotool error: {result.stderr.strip()}"
            
    except subprocess.TimeoutExpired:
        logger.error("❌ Timeout sending mouse click")
        return False, "xdotool timeout"
    except Exception as e:
        logger.error(f"❌ Exception sending mouse click: {e}")
        return False, f"Exception: {str(e)}"
```

### **Step 5: Update Health Check**

**ENHANCE** the health check to validate key injection readiness:

```python
async def health_check(self, request):
    """Enhanced health check including key injection validation"""
    try:
        # Basic health
        basic_health = {
            "status": "healthy",
            "timestamp": time.time(),
            "emulator_running": self.emulator_running,
            "uptime": time.time() - self.server_start_time
        }
        
        # Add key injection validation
        window_valid, window_id = self.validate_fuse_window()
        basic_health.update({
            "fuse_window_valid": window_valid,
            "fuse_window_id": window_id,
            "key_injection_ready": window_valid,
            "version": "v6-proven-keys"
        })
        
        status_code = 200 if window_valid else 503
        return web.json_response(basic_health, status=status_code)
        
    except Exception as e:
        return web.json_response({
            "status": "unhealthy",
            "error": str(e),
            "version": "v6-proven-keys"
        }, status=500)
```

## 🐳 **DOCKER IMAGE UPDATE**

### **Update Dockerfile**

**File**: Create `fixed-emulator-v6-keys.dockerfile`

```dockerfile
FROM ubuntu:22.04

# Install all required packages including xdotool
RUN apt-get update && apt-get install -y \
    fuse-emulator-sdl \
    ffmpeg \
    python3 \
    python3-pip \
    python3-websockets \
    python3-aiohttp \
    xvfb \
    pulseaudio \
    x11-utils \
    xdotool \
    awscli \
    && rm -rf /var/lib/apt/lists/*

# Create application directory
WORKDIR /app

# Copy server code
COPY server/emulator_server_fixed_v6.py /app/server.py
COPY server/requirements.txt /app/requirements.txt

# Install Python dependencies
RUN pip3 install -r requirements.txt

# Set environment variables
ENV DISPLAY=:99
ENV SDL_VIDEODRIVER=x11
ENV SDL_AUDIODRIVER=pulse
ENV PULSE_RUNTIME_PATH=/tmp/pulse

# Expose ports
EXPOSE 8765 8080

# Start script
CMD ["python3", "/app/server.py"]
```

### **Update Task Definition**

**File**: Create `task-definition-v6-keys.json`

```json
{
  "family": "spectrum-emulator-streaming",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "1024",
  "memory": "2048",
  "executionRoleArn": "arn:aws:iam::043309319786:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::043309319786:role/ecsTaskRole",
  "containerDefinitions": [
    {
      "name": "spectrum-emulator",
      "image": "043309319786.dkr.ecr.us-east-1.amazonaws.com/spectrum-emulator:v6-proven-keys",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8765,
          "protocol": "tcp"
        },
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "DISPLAY",
          "value": ":99"
        },
        {
          "name": "SDL_VIDEODRIVER",
          "value": "x11"
        },
        {
          "name": "STREAM_BUCKET",
          "value": "spectrum-emulator-stream-dev-043309319786"
        }
      ],
      "healthCheck": {
        "command": [
          "CMD-SHELL",
          "curl -f http://localhost:8080/health || exit 1"
        ],
        "interval": 30,
        "timeout": 10,
        "retries": 3,
        "startPeriod": 120
      },
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/spectrum-emulator-streaming",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

## 🚀 **DEPLOYMENT STEPS**

### **1. Create Updated Server File**
```bash
# Copy current server and apply the proven method changes
cp server/emulator_server_fixed_v5.py server/emulator_server_fixed_v6.py
# Then apply the code changes above
```

### **2. Build and Push Docker Image**
```bash
# Build new image
docker build -f fixed-emulator-v6-keys.dockerfile -t spectrum-emulator:v6-proven-keys .

# Tag for ECR
docker tag spectrum-emulator:v6-proven-keys \
  043309319786.dkr.ecr.us-east-1.amazonaws.com/spectrum-emulator:v6-proven-keys

# Push to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  043309319786.dkr.ecr.us-east-1.amazonaws.com

docker push 043309319786.dkr.ecr.us-east-1.amazonaws.com/spectrum-emulator:v6-proven-keys
```

### **3. Deploy to Development First**
```bash
# Register new task definition
aws ecs register-task-definition --cli-input-json file://task-definition-v6-keys.json

# Update development service
aws ecs update-service \
  --cluster spectrum-emulator-cluster-dev \
  --service spectrum-youtube-streaming \
  --task-definition spectrum-emulator-streaming:NEW_REVISION
```

### **4. Test Key Injection**
- Open your livestream: https://d112s3ps8xh739.cloudfront.net
- Try pressing keys via the web interface
- **You should see keys appear immediately on the livestream**
- Check health endpoint shows `"key_injection_ready": true`

## ✅ **SUCCESS CRITERIA**

- ✅ **Keys appear on livestream immediately** when pressed via web interface
- ✅ **WebSocket error 1011 eliminated** - no more connection errors
- ✅ **Health check reports** `"key_injection_ready": true`
- ✅ **Mouse clicks work** (if implemented)
- ✅ **No dropped key presses** in normal usage

## 🎯 **WHY THIS WILL WORK**

1. **Same Technology**: Identical xdotool + FUSE + Xvfb stack as proven local test
2. **Same Commands**: Exact same xdotool command pattern that we proved works
3. **Same Environment**: Same DISPLAY=:99 and window targeting approach
4. **Proven Method**: We have visual proof this method works locally

**The only difference is applying the proven method to your production WebSocket server instead of running it manually.**

## 🔧 **TROUBLESHOOTING**

If keys still don't work after deployment:

1. **Check Health Endpoint**: Should show `"fuse_window_valid": true`
2. **Check Logs**: Look for "✅ Successfully sent key" messages
3. **Test Window Detection**: Health check will show if FUSE window is found
4. **Verify xdotool**: Container should have xdotool installed

**This focused approach applies the exact proven method to solve your remote control problem without unnecessary features.**
