# Production Implementation Plan - Key Injection Integration

## 🎯 **Objective**

Convert the main SpeccyEmulator project to use the **proven local test method** for reliable key injection in the AWS production environment.

## 📋 **Current State Analysis**

### **✅ What's Already Working**
- **AWS Infrastructure**: ECS, CloudFront, S3, ALB all operational
- **Video Streaming**: HLS pipeline functional
- **WebSocket Server**: Basic connectivity established
- **Docker Images**: Pre-built images with dependencies
- **Core Technology**: Same Xvfb + FUSE + xdotool stack

### **🔧 What Needs Implementation**
- **Reliable Key Injection**: Apply proven xdotool method
- **WebSocket Message Handling**: Fix error 1011 issues
- **Visual Verification**: Add screenshot-based testing
- **Error Handling**: Robust failure detection and recovery

## 🚀 **Implementation Phases**

### **Phase 1: Server Code Integration** (Priority: HIGH)

#### **1.1 Update Key Injection Method**

**Current Issue**: WebSocket server has error 1011 in message processing
**Solution**: Apply proven xdotool pattern from local tests

**Files to Modify**:
- `server/emulator_server_fixed_v5.py`

**Changes Required**:

```python
# BEFORE (current problematic method)
def send_key_to_emulator(self, key):
    # Complex error-prone implementation
    
# AFTER (proven method from local test)
def send_key_to_emulator(self, key):
    """Send key press to FUSE emulator using proven xdotool method"""
    try:
        if not self.emulator_running:
            logger.warning(f"Emulator not running, ignoring key: {key}")
            return False, "Emulator not running"
            
        # Map the key to X11 key name (from proven local test)
        x11_key = self.key_mapping.get(key, key.lower())
        
        # Use EXACT command pattern from successful local test
        result = subprocess.run([
            'xdotool', 
            'search', '--name', 'Fuse',
            'windowfocus',
            'key', x11_key
        ], env={'DISPLAY': ':99'}, capture_output=True, text=True, timeout=5)
        
        if result.returncode == 0:
            logger.info(f"✅ Successfully sent key '{key}' (mapped to '{x11_key}')")
            return True, f"Key '{key}' sent successfully"
        else:
            logger.error(f"❌ Failed to send key '{key}': {result.stderr}")
            return False, f"xdotool error: {result.stderr.strip()}"
            
    except subprocess.TimeoutExpired:
        logger.error(f"❌ Timeout sending key '{key}'")
        return False, "xdotool timeout"
    except Exception as e:
        logger.error(f"❌ Exception sending key '{key}': {e}")
        return False, f"Exception: {str(e)}"
```

#### **1.2 Add Window Detection Validation**

```python
def validate_fuse_window(self):
    """Validate FUSE window exists and is accessible"""
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
            
    except Exception as e:
        logger.error(f"❌ Error finding FUSE window: {e}")
        return False, None
```

#### **1.3 Fix WebSocket Message Handling**

**Current Issue**: Error 1011 in WebSocket processing
**Solution**: Simplify message handling based on working local test

```python
async def handle_message(self, websocket, data):
    """Handle WebSocket messages with improved error handling"""
    try:
        if data.get('type') == 'key_press':
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
            
        elif data.get('type') == 'ping':
            await websocket.send(json.dumps({
                "type": "pong",
                "timestamp": time.time()
            }))
            
        else:
            await websocket.send(json.dumps({
                "type": "error",
                "message": f"Unknown message type: {data.get('type')}"
            }))
            
    except Exception as e:
        logger.error(f"Error handling message: {e}")
        await websocket.send(json.dumps({
            "type": "error",
            "message": str(e)
        }))
```

### **Phase 2: Visual Verification Integration** (Priority: MEDIUM)

#### **2.1 Add Screenshot Testing to Production**

**Purpose**: Same visual proof method used in local tests
**Implementation**: Add screenshot capture capability to production server

```python
def capture_screenshot(self, filename_prefix="screenshot"):
    """Capture FUSE emulator screenshot for verification"""
    try:
        # Find FUSE window
        window_valid, window_id = self.validate_fuse_window()
        if not window_valid:
            return False, "FUSE window not found"
        
        # Capture screenshot
        timestamp = int(time.time())
        screenshot_path = f"/tmp/{filename_prefix}_{timestamp}.xwd"
        
        result = subprocess.run([
            'xwd', '-display', ':99', '-id', window_id, '-out', screenshot_path
        ], capture_output=True, text=True, timeout=10)
        
        if result.returncode == 0:
            logger.info(f"✅ Screenshot captured: {screenshot_path}")
            
            # Convert to PNG if possible
            png_path = screenshot_path.replace('.xwd', '.png')
            convert_result = subprocess.run([
                'convert', screenshot_path, png_path
            ], capture_output=True, text=True)
            
            if convert_result.returncode == 0:
                return True, png_path
            else:
                return True, screenshot_path
                
        else:
            logger.error(f"❌ Screenshot failed: {result.stderr}")
            return False, result.stderr
            
    except Exception as e:
        logger.error(f"❌ Screenshot exception: {e}")
        return False, str(e)
```

#### **2.2 Add Visual Testing Endpoint**

```python
async def handle_visual_test(self, websocket, data):
    """Handle visual testing requests"""
    try:
        # Take before screenshot
        before_success, before_path = self.capture_screenshot("before")
        if not before_success:
            await websocket.send(json.dumps({
                "type": "visual_test_error",
                "message": f"Before screenshot failed: {before_path}"
            }))
            return
        
        # Send test keys
        test_sequence = data.get('test_keys', ['H', 'E', 'L', 'L', 'O'])
        for key in test_sequence:
            success, message = self.send_key_to_emulator(key)
            if not success:
                logger.warning(f"Key {key} failed: {message}")
        
        # Wait for processing
        await asyncio.sleep(1)
        
        # Take after screenshot
        after_success, after_path = self.capture_screenshot("after")
        if not after_success:
            await websocket.send(json.dumps({
                "type": "visual_test_error",
                "message": f"After screenshot failed: {after_path}"
            }))
            return
        
        # Compare screenshots
        screenshots_different = not subprocess.run([
            'cmp', '-s', before_path, after_path
        ]).returncode == 0
        
        # Upload to S3 for viewing
        s3_before = await self.upload_screenshot_to_s3(before_path, "visual_test_before.png")
        s3_after = await self.upload_screenshot_to_s3(after_path, "visual_test_after.png")
        
        # Send results
        await websocket.send(json.dumps({
            "type": "visual_test_result",
            "screenshots_different": screenshots_different,
            "test_sequence": test_sequence,
            "before_url": s3_before,
            "after_url": s3_after,
            "conclusion": "Key injection WORKS" if screenshots_different else "Key injection FAILED"
        }))
        
    except Exception as e:
        logger.error(f"Visual test error: {e}")
        await websocket.send(json.dumps({
            "type": "visual_test_error",
            "message": str(e)
        }))
```

### **Phase 3: Docker Image Updates** (Priority: HIGH)

#### **3.1 Update Dockerfile**

**File**: `fixed-emulator-v5.dockerfile` (or create new version)

**Additions Required**:
```dockerfile
# Ensure all required tools are installed
RUN apt-get update && apt-get install -y \
    xdotool \
    x11-utils \
    imagemagick \
    && rm -rf /var/lib/apt/lists/*

# Add screenshot directory
RUN mkdir -p /tmp/screenshots

# Copy updated server code
COPY server/emulator_server_fixed_v6.py /app/server.py
```

#### **3.2 Build and Deploy New Image**

```bash
# Build new image with proven method
docker build -f fixed-emulator-v6.dockerfile -t spectrum-emulator:v6-proven-keys .

# Tag for ECR
docker tag spectrum-emulator:v6-proven-keys \
  043309319786.dkr.ecr.us-east-1.amazonaws.com/spectrum-emulator:v6-proven-keys

# Push to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  043309319786.dkr.ecr.us-east-1.amazonaws.com

docker push 043309319786.dkr.ecr.us-east-1.amazonaws.com/spectrum-emulator:v6-proven-keys
```

### **Phase 4: Frontend Integration** (Priority: MEDIUM)

#### **4.1 Add Visual Testing Interface**

**File**: `web/js/spectrum-emulator.js`

**Add Visual Test Function**:
```javascript
function runVisualTest() {
    if (!websocket || websocket.readyState !== WebSocket.OPEN) {
        console.error('WebSocket not connected');
        return;
    }
    
    const testMessage = {
        type: 'visual_test',
        test_keys: ['H', 'E', 'L', 'L', 'O', 'SPACE', 'T', 'E', 'S', 'T']
    };
    
    websocket.send(JSON.stringify(testMessage));
    
    // Show loading indicator
    document.getElementById('visual-test-status').innerHTML = 
        '🧪 Running visual test... Taking screenshots and comparing results.';
}

// Handle visual test results
function handleVisualTestResult(data) {
    const statusDiv = document.getElementById('visual-test-status');
    
    if (data.screenshots_different) {
        statusDiv.innerHTML = `
            ✅ <strong>Visual Test PASSED!</strong><br>
            Key injection is working correctly.<br>
            <a href="${data.before_url}" target="_blank">Before Screenshot</a> | 
            <a href="${data.after_url}" target="_blank">After Screenshot</a>
        `;
    } else {
        statusDiv.innerHTML = `
            ❌ <strong>Visual Test FAILED!</strong><br>
            No visual changes detected. Key injection may not be working.<br>
            <a href="${data.before_url}" target="_blank">Before Screenshot</a> | 
            <a href="${data.after_url}" target="_blank">After Screenshot</a>
        `;
    }
}
```

#### **4.2 Add Visual Test UI**

**File**: `web/index.html`

**Add Test Interface**:
```html
<!-- Add to existing interface -->
<div class="visual-test-section">
    <h3>🧪 Visual Testing</h3>
    <button onclick="runVisualTest()" class="test-button">
        Run Visual Key Test
    </button>
    <div id="visual-test-status" class="test-status">
        Click "Run Visual Key Test" to verify key injection is working
    </div>
</div>
```

### **Phase 5: Deployment Strategy** (Priority: HIGH)

#### **5.1 Staged Rollout Plan**

**Step 1: Create New Task Definition**
```bash
# Create task definition with v6-proven-keys image
aws ecs register-task-definition \
  --family spectrum-emulator-streaming \
  --cli-input-json file://task-definition-v6-proven-keys.json
```

**Step 2: Test in Development Environment**
```bash
# Update development service first
aws ecs update-service \
  --cluster spectrum-emulator-cluster-dev \
  --service spectrum-youtube-streaming \
  --task-definition spectrum-emulator-streaming:NEW_REVISION
```

**Step 3: Validate with Visual Tests**
- Run visual tests via web interface
- Verify screenshots show key injection working
- Check WebSocket error logs are resolved

**Step 4: Production Deployment**
- Only deploy to production after development validation
- Monitor health checks and error rates
- Have rollback plan ready

#### **5.2 Monitoring and Validation**

**Health Check Enhancements**:
```python
async def enhanced_health_check(self, request):
    """Enhanced health check including key injection validation"""
    try:
        # Basic health
        basic_health = await self.health_check(request)
        
        # Add key injection validation
        window_valid, window_id = self.validate_fuse_window()
        
        health_data = {
            "status": "healthy" if window_valid else "degraded",
            "timestamp": time.time(),
            "fuse_window": window_id if window_valid else None,
            "key_injection_ready": window_valid,
            "version": "v6-proven-keys"
        }
        
        return web.json_response(health_data)
        
    except Exception as e:
        return web.json_response({
            "status": "unhealthy",
            "error": str(e)
        }, status=500)
```

## 📊 **Success Metrics**

### **Technical Metrics**
- ✅ WebSocket error 1011 eliminated
- ✅ Key injection success rate > 95%
- ✅ Visual tests show `screenshots_different: true`
- ✅ FUSE window detection success rate > 99%

### **User Experience Metrics**
- ✅ Key presses appear on screen within 500ms
- ✅ No dropped key presses in normal usage
- ✅ Visual feedback confirms key processing
- ✅ Error messages are clear and actionable

### **Operational Metrics**
- ✅ Container startup time < 2 minutes
- ✅ Health checks pass consistently
- ✅ No increase in error rates
- ✅ Screenshot capture works reliably

## 🔧 **Testing Strategy**

### **Pre-Deployment Testing**
1. **Local Validation**: Run proven local tests
2. **Docker Testing**: Test new image locally
3. **Development Deployment**: Deploy to dev environment
4. **Visual Testing**: Run screenshot comparisons
5. **Load Testing**: Test with multiple concurrent users

### **Post-Deployment Validation**
1. **Immediate Testing**: Run visual tests after deployment
2. **Monitoring**: Watch error rates and health checks
3. **User Testing**: Verify key presses work in web interface
4. **Screenshot Archive**: Keep visual proof of functionality

## 📋 **Implementation Checklist**

### **Phase 1: Server Code** 
- [ ] Update `send_key_to_emulator()` method
- [ ] Add `validate_fuse_window()` function
- [ ] Fix WebSocket message handling
- [ ] Add comprehensive error handling
- [ ] Add timeout protection

### **Phase 2: Visual Verification**
- [ ] Add `capture_screenshot()` method
- [ ] Implement visual test endpoint
- [ ] Add S3 screenshot upload
- [ ] Create screenshot comparison logic

### **Phase 3: Docker & Deployment**
- [ ] Update Dockerfile with required tools
- [ ] Build and test new Docker image
- [ ] Create new task definition
- [ ] Deploy to development environment
- [ ] Validate functionality

### **Phase 4: Frontend Integration**
- [ ] Add visual test JavaScript functions
- [ ] Create visual test UI components
- [ ] Handle visual test results
- [ ] Add screenshot viewing links

### **Phase 5: Production Rollout**
- [ ] Deploy to production
- [ ] Run comprehensive visual tests
- [ ] Monitor error rates and health
- [ ] Document final configuration

## 🎯 **Expected Outcomes**

### **Immediate Results**
- **WebSocket Error 1011**: Eliminated
- **Key Injection**: 100% functional with visual proof
- **User Experience**: Immediate key response on screen
- **Debugging**: Screenshot-based troubleshooting available

### **Long-term Benefits**
- **Reliability**: Proven method reduces key injection failures
- **Maintainability**: Clear visual testing for future changes
- **Scalability**: Robust foundation for additional features
- **User Confidence**: Visual proof that system works correctly

## 🚀 **Next Steps**

1. **Start with Phase 1**: Update server code with proven method
2. **Test Locally**: Validate changes using local test setup
3. **Build New Image**: Create v6-proven-keys Docker image
4. **Deploy to Dev**: Test in development environment first
5. **Add Visual Testing**: Implement screenshot comparison
6. **Production Rollout**: Deploy with confidence

**The proven local test method provides a clear roadmap for reliable production implementation with visual verification of success.**
