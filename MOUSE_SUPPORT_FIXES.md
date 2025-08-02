# Mouse Support and Cursor Hiding Implementation

## 🔍 **Issues Identified**

### **Problems Found:**
1. **Visible Mouse Cursor**: Mouse pointer was being captured in the video stream
2. **No Mouse Input**: ZX Spectrum emulator supports mouse but no input method was provided
3. **Missing Interaction**: Users couldn't click directly on the video to interact with emulator

## ✅ **Fixes Implemented**

### **1. Hide Mouse Cursor from Video Capture**

**Server-Side FFmpeg Fix:**
```python
# HLS Stream
'-draw_mouse', '0',  # Hide mouse cursor from capture

# YouTube Stream  
'-draw_mouse', '0',  # Hide mouse cursor from capture
```

**Result**: Mouse cursor no longer appears in video streams

### **2. Added Mouse Input Support**

**Backend Implementation (`emulator_server_fixed_v5.py`):**

**New Method - `send_mouse_click_to_emulator()`:**
```python
def send_mouse_click_to_emulator(self, button, x=None, y=None):
    """Send mouse click to emulator using xdotool"""
    # Supports: left, right, middle, scroll_up, scroll_down
    # Optional coordinates for precise clicking
    # Uses xdotool to send clicks to FUSE emulator window
```

**Features:**
- ✅ **Button Support**: Left, right, middle, scroll up/down
- ✅ **Coordinate Support**: Optional x,y coordinates for precise clicking
- ✅ **Window Targeting**: Uses xdotool to target FUSE emulator window
- ✅ **Bounds Checking**: Ensures coordinates are within 256x192 emulator bounds
- ✅ **Error Handling**: Comprehensive error reporting and logging

**WebSocket Message Handling:**
```python
elif data.get('type') == 'mouse_click':
    button = data.get('button', 'left')
    x = data.get('x')  # Optional coordinates
    y = data.get('y')
    
    success, message = self.send_mouse_click_to_emulator(button, x, y)
    # Send response with processing status
```

### **3. Frontend Mouse Integration**

**JavaScript Implementation (`spectrum-emulator.js`):**

**New Method - `sendMouseClick()`:**
```javascript
sendMouseClick(button, x = null, y = null) {
    const message = { 
        type: 'mouse_click', 
        button: button,
        x: Math.round(x),
        y: Math.round(y),
        timestamp: Date.now()
    };
    // Send via WebSocket
}
```

**New Method - `setupMouse()`:**
```javascript
setupMouse() {
    const video = document.getElementById('videoPlayer');
    
    // Left click support
    video.addEventListener('click', (e) => {
        const rect = video.getBoundingClientRect();
        const x = ((e.clientX - rect.left) / rect.width) * 256;
        const y = ((e.clientY - rect.top) / rect.height) * 192;
        this.sendMouseClick('left', x, y);
    });
    
    // Right click support
    video.addEventListener('contextmenu', (e) => {
        e.preventDefault();
        // Calculate coordinates and send right click
    });
}
```

**Features:**
- ✅ **Coordinate Mapping**: Converts browser coordinates to ZX Spectrum 256x192 space
- ✅ **Left Click**: Standard left mouse button support
- ✅ **Right Click**: Right mouse button with context menu prevention
- ✅ **Visual Feedback**: Crosshair cursor on video player
- ✅ **Precise Positioning**: Accurate coordinate calculation

### **4. UI Enhancements**

**Updated Interactive Controls Description:**
```html
<strong>🎮 Interactive Controls:</strong> Use your physical keyboard, click the virtual keys below, or <strong>🖱️ click directly on the video</strong> to interact with the ZX Spectrum emulator in real-time!
```

**Visual Enhancements:**
- ✅ **Crosshair Cursor**: Video shows crosshair when hovering
- ✅ **Updated Instructions**: Clear guidance on mouse usage
- ✅ **Feature Indication**: Server reports 'mouse_support' in features list

## 🎯 **Technical Implementation Details**

### **Coordinate System Mapping:**
1. **Browser Click**: User clicks at (clientX, clientY) on video element
2. **Video Bounds**: Calculate relative position within video rectangle
3. **Scale to Emulator**: Convert to ZX Spectrum coordinates (0-255, 0-191)
4. **Send to Server**: WebSocket message with precise coordinates
5. **xdotool Execution**: Server sends click to FUSE emulator window

### **Message Protocol:**
```json
// Client to Server
{
  "type": "mouse_click",
  "button": "left",
  "x": 128,
  "y": 96,
  "timestamp": 1691234567890
}

// Server to Client
{
  "type": "mouse_response",
  "button": "left",
  "x": 128,
  "y": 96,
  "processed": true,
  "message": "Mouse left click at (128,96) processed successfully",
  "timestamp": 1691234567891
}
```

### **Supported Mouse Actions:**
- ✅ **Left Click**: Primary interaction
- ✅ **Right Click**: Secondary interaction  
- ✅ **Coordinate-based**: Precise positioning
- ✅ **Window-targeted**: Clicks sent to correct emulator window

## 📊 **Expected Results**

### **Video Stream:**
- ✅ **No Cursor**: Mouse pointer no longer visible in stream
- ✅ **Clean Video**: Pure emulator output without desktop artifacts

### **Mouse Interaction:**
- ✅ **Click Response**: Emulator responds to mouse clicks
- ✅ **Precise Positioning**: Accurate coordinate mapping
- ✅ **Visual Feedback**: Crosshair cursor indicates interactive area
- ✅ **Real-time**: Immediate response to mouse actions

### **User Experience:**
- ✅ **Intuitive**: Natural point-and-click interaction
- ✅ **Responsive**: Low-latency mouse input
- ✅ **Accurate**: Precise coordinate translation
- ✅ **Complete**: Both left and right click support

## 🚀 **Files Modified**

1. **`server/emulator_server_fixed_v5.py`**:
   - Added `-draw_mouse 0` to FFmpeg commands
   - Added `send_mouse_click_to_emulator()` method
   - Added mouse_click WebSocket message handling
   - Added 'mouse_support' to features list

2. **`web/js/spectrum-emulator.js`**:
   - Added `sendMouseClick()` method
   - Added `setupMouse()` method
   - Added mouse event listeners to video player
   - Added coordinate mapping logic

3. **`web/index.html`**:
   - Updated interactive controls description
   - Added mouse support information

## ✅ **Ready for Deployment**

These changes provide complete mouse support while hiding the cursor from video streams. The implementation includes:
- Server-side cursor hiding via FFmpeg
- Complete mouse input pipeline via xdotool
- Frontend coordinate mapping and event handling
- Real-time WebSocket communication
- Comprehensive error handling and logging

The ZX Spectrum emulator now supports both keyboard and mouse interaction with a clean, cursor-free video stream!
