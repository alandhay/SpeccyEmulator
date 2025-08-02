class SpectrumEmulator {
    constructor() {
        this.ws = null;
        this.hls = null;
        this.connected = false;
        this.emulatorRunning = false;
        this.reconnectAttempts = 0;
        this.maxReconnectAttempts = 5;
        
        this.init();
    }

    init() {
        this.setupHLS();
        this.connectWebSocket();
        this.setupKeyboard();
        this.setupPhysicalKeyboard();
        this.setupMouse();
        this.log('🎮 Initializing HIGH QUALITY ZX Spectrum Emulator Interface...', 'info');
        this.log('📺 Connecting to live emulator stream...', 'info');
    }

    setupHLS() {
        const video = document.getElementById('videoPlayer');
        const streamUrl = 'https://spectrum-emulator-stream-dev-043309319786.s3.us-east-1.amazonaws.com/hls/stream.m3u8?t=' + Date.now();

        if (Hls.isSupported()) {
            this.hls = new Hls({
                debug: false,
                enableWorker: true,
                lowLatencyMode: true,
                backBufferLength: 30,
                maxBufferLength: 60,
                maxMaxBufferLength: 120,
                liveSyncDurationCount: 3,
                liveMaxLatencyDurationCount: 5
            });
            
            this.hls.loadSource(streamUrl);
            this.hls.attachMedia(video);
            
            this.hls.on(Hls.Events.MANIFEST_PARSED, () => {
                this.log('📺 HIGH QUALITY Stream connected successfully!', 'success');
                this.updateStreamInfo('Live HIGH QUALITY Emulator Stream');
                video.play().catch(e => {
                    this.log('⚠️ Autoplay blocked - click video to start', 'info');
                });
            });

            this.hls.on(Hls.Events.LEVEL_LOADED, (event, data) => {
                this.log(`📊 Stream quality: ${data.details.totalduration}s segments`, 'info');
            });

            this.hls.on(Hls.Events.ERROR, (event, data) => {
                this.log(`❌ Stream error: ${data.type} - ${data.details}`, 'error');
                if (data.fatal) {
                    switch (data.type) {
                        case Hls.ErrorTypes.NETWORK_ERROR:
                            this.log('🔄 Recovering from network error...', 'info');
                            this.hls.startLoad();
                            break;
                        case Hls.ErrorTypes.MEDIA_ERROR:
                            this.log('🔄 Recovering from media error...', 'info');
                            this.hls.recoverMediaError();
                            break;
                        default:
                            this.log('💥 Fatal error - reloading stream...', 'error');
                            this.hls.destroy();
                            setTimeout(() => this.setupHLS(), 3000);
                            break;
                    }
                }
            });
        } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
            video.src = streamUrl;
            this.log('📺 Using native HLS support', 'info');
        } else {
            this.log('❌ HLS not supported in this browser', 'error');
        }
    }

    connectWebSocket() {
        const wsUrl = CONFIG.WEBSOCKET_URL;
        this.log(`🔌 Connecting to HIGH QUALITY server at ${wsUrl}...`, 'info');

        try {
            this.ws = new WebSocket(wsUrl);
            
            this.ws.onopen = () => {
                this.connected = true;
                this.reconnectAttempts = 0;
                this.updateConnectionStatus(true);
                this.log('✅ Connected to HIGH QUALITY emulator server!', 'success');
                
                // Auto-request status to check if emulator is already running
                setTimeout(() => {
                    this.sendMessage({ type: 'status' });
                    this.log('🔍 Checking HIGH QUALITY emulator status...', 'info');
                }, 1000);
            };

            this.ws.onmessage = (event) => {
                try {
                    const data = JSON.parse(event.data);
                    this.handleMessage(data);
                } catch (e) {
                    this.log(`❌ Invalid message received: ${event.data}`, 'error');
                }
            };

            this.ws.onclose = () => {
                this.connected = false;
                this.updateConnectionStatus(false);
                this.log('🔌 Connection closed', 'error');
                this.attemptReconnect();
            };

            this.ws.onerror = (error) => {
                this.log('❌ WebSocket error occurred', 'error');
            };
        } catch (error) {
            this.log(`❌ Failed to connect: ${error.message}`, 'error');
            this.attemptReconnect();
        }
    }

    attemptReconnect() {
        if (this.reconnectAttempts < this.maxReconnectAttempts) {
            this.reconnectAttempts++;
            const delay = Math.min(1000 * Math.pow(2, this.reconnectAttempts), 10000);
            this.log(`🔄 Reconnecting in ${delay/1000}s... (${this.reconnectAttempts}/${this.maxReconnectAttempts})`, 'info');
            setTimeout(() => this.connectWebSocket(), delay);
        } else {
            this.log('❌ Max reconnection attempts reached', 'error');
        }
    }

    handleMessage(data) {
        switch (data.type) {
            case 'connected':
                this.log(`🎬 Connected: ${data.message || 'HIGH QUALITY server ready'}`, 'success');
                if (data.output_resolution) {
                    this.updateQualityStatus(`${data.output_resolution} @ ${data.video_bitrate || 'HIGH QUALITY'}`);
                }
                if (data.quality) {
                    this.updateQualityStatus(data.quality);
                }
                // Check if emulator is already running
                if (data.emulator_running) {
                    this.emulatorRunning = true;
                    this.updateEmulatorStatus(true);
                    this.log('🎮 HIGH QUALITY Emulator is already running!', 'success');
                }
                break;
            
            case 'emulator_status':
                this.emulatorRunning = data.running;
                this.updateEmulatorStatus(data.running);
                this.log(`📊 Emulator Status: ${data.message}`, data.running ? 'success' : 'info');
                if (data.output_resolution) {
                    this.updateQualityStatus(`${data.output_resolution} @ ${data.video_bitrate || 'HIGH QUALITY'}`);
                }
                if (data.running) {
                    this.updateStreamInfo('Live HIGH QUALITY Emulator Stream');
                } else {
                    this.updateStreamInfo('HIGH QUALITY Test Pattern');
                }
                break;
            
            case 'key_response':
                if (data.success) {
                    this.log(`✅ Key ${data.action}: ${data.key}`, 'success');
                } else {
                    this.log(`❌ Key ${data.action} failed: ${data.key} - ${data.error}`, 'error');
                }
                break;
            
            case 'emulator_output':
                // Handle any text output from the emulator
                if (data.text) {
                    this.log(`🖥️ Emulator: ${data.text}`, 'info');
                }
                break;
            
            case 'error':
                this.log(`❌ Error: ${data.message}`, 'error');
                break;
            
            default:
                this.log(`📨 ${data.message || JSON.stringify(data)}`, 'info');
        }
    }

    sendMessage(message) {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(JSON.stringify(message));
            return true;
        } else {
            this.log('❌ Not connected to server', 'error');
            return false;
        }
    }

    setupKeyboard() {
        document.querySelectorAll('.key').forEach(key => {
            // Track if this key is currently pressed via mouse
            let mousePressed = false;
            
            // Mouse down - key press
            key.addEventListener('mousedown', (e) => {
                e.preventDefault();
                if (!mousePressed) {
                    mousePressed = true;
                    const keyValue = key.dataset.key;
                    this.sendKey(keyValue, 'press');
                    this.visualKeyPress(key, true);
                }
            });
            
            // Mouse up - key release (only if we pressed it)
            key.addEventListener('mouseup', (e) => {
                e.preventDefault();
                if (mousePressed) {
                    mousePressed = false;
                    const keyValue = key.dataset.key;
                    this.sendKey(keyValue, 'release');
                    this.visualKeyPress(key, false);
                }
            });
            
            // Mouse leave - release key only if it was pressed via mouse
            key.addEventListener('mouseleave', (e) => {
                if (mousePressed) {
                    mousePressed = false;
                    const keyValue = key.dataset.key;
                    this.sendKey(keyValue, 'release');
                    this.visualKeyPress(key, false);
                }
            });
            
            // Touch support for mobile
            key.addEventListener('touchstart', (e) => {
                e.preventDefault();
                const keyValue = key.dataset.key;
                this.sendKey(keyValue, 'press');
                this.visualKeyPress(key, true);
            });
            
            key.addEventListener('touchend', (e) => {
                e.preventDefault();
                const keyValue = key.dataset.key;
                this.sendKey(keyValue, 'release');
                this.visualKeyPress(key, false);
            });
        });
    }
    
    visualKeyPress(keyElement, pressed) {
        if (pressed) {
            keyElement.style.transform = 'translateY(2px)';
            keyElement.style.background = 'linear-gradient(145deg, #00ff00, #00cc00)';
            keyElement.style.color = '#000';
            keyElement.style.boxShadow = 'inset 0 2px 4px rgba(0,0,0,0.3)';
        } else {
            keyElement.style.transform = '';
            keyElement.style.background = '';
            keyElement.style.color = '';
            keyElement.style.boxShadow = '';
        }
    }

    setupPhysicalKeyboard() {
        // Track pressed keys to avoid repeats
        this.pressedKeys = new Set();
        
        document.addEventListener('keydown', (event) => {
            if (event.target.tagName === 'INPUT' || event.target.tagName === 'TEXTAREA') {
                return; // Don't intercept when typing in inputs
            }
            
            // Prevent key repeat
            if (this.pressedKeys.has(event.code)) {
                event.preventDefault();
                return;
            }
            
            event.preventDefault();
            this.pressedKeys.add(event.code);
            
            let key = this.mapPhysicalKeyToSpectrum(event);
            
            if (key) {
                this.sendKey(key, 'press');
            }
        });
        
        document.addEventListener('keyup', (event) => {
            if (event.target.tagName === 'INPUT' || event.target.tagName === 'TEXTAREA') {
                return;
            }
            
            event.preventDefault();
            this.pressedKeys.delete(event.code);
            
            let key = this.mapPhysicalKeyToSpectrum(event);
            
            if (key) {
                this.sendKey(key, 'release');
            }
        });
        
        // Clear pressed keys when window loses focus
        window.addEventListener('blur', () => {
            this.pressedKeys.clear();
        });
    }
    
    mapPhysicalKeyToSpectrum(event) {
        // Map physical keyboard to ZX Spectrum layout
        const keyMap = {
            // Numbers
            'Digit1': '1', 'Digit2': '2', 'Digit3': '3', 'Digit4': '4', 'Digit5': '5',
            'Digit6': '6', 'Digit7': '7', 'Digit8': '8', 'Digit9': '9', 'Digit0': '0',
            
            // Letters (QWERTY layout)
            'KeyQ': 'Q', 'KeyW': 'W', 'KeyE': 'E', 'KeyR': 'R', 'KeyT': 'T',
            'KeyY': 'Y', 'KeyU': 'U', 'KeyI': 'I', 'KeyO': 'O', 'KeyP': 'P',
            'KeyA': 'A', 'KeyS': 'S', 'KeyD': 'D', 'KeyF': 'F', 'KeyG': 'G',
            'KeyH': 'H', 'KeyJ': 'J', 'KeyK': 'K', 'KeyL': 'L',
            'KeyZ': 'Z', 'KeyX': 'X', 'KeyC': 'C', 'KeyV': 'V', 'KeyB': 'B',
            'KeyN': 'N', 'KeyM': 'M',
            
            // Special keys
            'Space': 'SPACE',
            'Enter': 'ENTER',
            'ShiftLeft': 'SHIFT',
            'ShiftRight': 'SHIFT',
            'ControlLeft': 'SYMBOL',
            'ControlRight': 'SYMBOL',
            'AltLeft': 'SYMBOL',
            'AltRight': 'SYMBOL',
            'Backspace': 'DELETE',
            'Delete': 'DELETE',
            
            // Arrow keys (mapped to QAOP for games)
            'ArrowUp': 'Q',
            'ArrowLeft': 'A',
            'ArrowDown': 'O',
            'ArrowRight': 'P',
            
            // Alternative cursor keys
            'KeyI': 'UP',    // When used as cursor
            'KeyJ': 'LEFT',  // When used as cursor
            'KeyK': 'DOWN',  // When used as cursor
            'KeyL': 'RIGHT'  // When used as cursor
        };
        
        return keyMap[event.code] || null;
    }

    setupMouse() {
        const video = document.getElementById('videoPlayer');
        if (!video) {
            this.log('⚠️ Video player not found for mouse setup', 'warning');
            return;
        }

        // Add mouse click listeners to video player
        video.addEventListener('click', (e) => {
            e.preventDefault();
            
            // Calculate relative coordinates within the video
            const rect = video.getBoundingClientRect();
            const x = ((e.clientX - rect.left) / rect.width) * 256;  // Scale to ZX Spectrum width
            const y = ((e.clientY - rect.top) / rect.height) * 192;  // Scale to ZX Spectrum height
            
            // Send left click with coordinates
            this.sendMouseClick('left', x, y);
        });

        // Right click support
        video.addEventListener('contextmenu', (e) => {
            e.preventDefault();
            
            // Calculate relative coordinates within the video
            const rect = video.getBoundingClientRect();
            const x = ((e.clientX - rect.left) / rect.width) * 256;  // Scale to ZX Spectrum width
            const y = ((e.clientY - rect.top) / rect.height) * 192;  // Scale to ZX Spectrum height
            
            // Send right click with coordinates
            this.sendMouseClick('right', x, y);
        });

        // Add visual feedback for mouse interaction
        video.style.cursor = 'crosshair';
        
        this.log('🖱️ Mouse support enabled - click on video to interact with emulator', 'info');
    }

    sendKey(key, action = 'press') {
        const message = { 
            type: 'key_input', 
            key: key, 
            action: action,
            timestamp: Date.now()
        };
        
        if (this.sendMessage(message)) {
            this.log(`⌨️ Key ${action}: ${key}`, 'info');
            
            // Visual feedback for physical keyboard
            if (action === 'press') {
                const keyElement = document.querySelector(`[data-key="${key}"]`);
                if (keyElement) {
                    this.visualKeyPress(keyElement, true);
                    // Auto-release visual after short delay if no release event
                    setTimeout(() => {
                        if (keyElement.style.transform) {
                            this.visualKeyPress(keyElement, false);
                        }
                    }, 150);
                }
            }
        }
    }

    sendMouseClick(button, x = null, y = null) {
        const message = { 
            type: 'mouse_click', 
            button: button,
            timestamp: Date.now()
        };
        
        // Add coordinates if provided
        if (x !== null && y !== null) {
            message.x = Math.round(x);
            message.y = Math.round(y);
        }
        
        if (this.sendMessage(message)) {
            const coordInfo = (x !== null && y !== null) ? ` at (${Math.round(x)},${Math.round(y)})` : '';
            this.log(`🖱️ Mouse ${button} click${coordInfo}`, 'info');
        }
    }

    updateConnectionStatus(connected) {
        const status = document.getElementById('connectionStatus');
        if (connected) {
            status.textContent = '⚡ Connected (HQ)';
            status.className = 'status-item status-connected';
        } else {
            status.textContent = '⚡ Disconnected';
            status.className = 'status-item status-disconnected';
        }
    }

    updateEmulatorStatus(running) {
        const status = document.getElementById('emulatorStatus');
        const startBtn = document.getElementById('startBtn');
        const stopBtn = document.getElementById('stopBtn');
        
        if (running) {
            status.textContent = '🎮 Running (HQ)';
            status.className = 'status-item status-connected';
            startBtn.disabled = true;
            stopBtn.disabled = false;
        } else {
            status.textContent = '🎯 Ready (HQ)';
            status.className = 'status-item';
            startBtn.disabled = false;
            stopBtn.disabled = true;
        }
    }

    updateQualityStatus(quality) {
        const status = document.getElementById('qualityStatus');
        status.textContent = `🎬 ${quality}`;
    }

    updateStreamInfo(info) {
        const streamInfo = document.getElementById('streamInfo');
        streamInfo.textContent = info;
    }

    log(message, type = 'info') {
        const logContent = document.getElementById('logContent');
        const timestamp = new Date().toLocaleTimeString();
        const entry = document.createElement('div');
        entry.className = `log-entry ${type}`;
        entry.textContent = `[${timestamp}] ${message}`;
        
        logContent.appendChild(entry);
        logContent.scrollTop = logContent.scrollHeight;
        
        // Keep only last 50 entries
        while (logContent.children.length > 50) {
            logContent.removeChild(logContent.firstChild);
        }
    }
}

// Global functions for buttons
let emulator;

function startEmulator() {
    if (emulator.sendMessage({ type: 'start_emulator' })) {
        emulator.log('🚀 Starting HIGH QUALITY emulator...', 'info');
    }
}

function stopEmulator() {
    if (emulator.sendMessage({ type: 'stop_emulator' })) {
        emulator.log('⏹️ Stopping HIGH QUALITY emulator...', 'info');
    }
}

function requestStatus() {
    if (emulator.sendMessage({ type: 'status' })) {
        emulator.log('📊 Requesting HIGH QUALITY status...', 'info');
    }
}

function takeScreenshot() {
    if (emulator.sendMessage({ type: 'screenshot' })) {
        emulator.log('📸 Taking screenshot...', 'info');
    }
}

function sendCommand(command) {
    if (emulator.sendMessage({ type: 'command', command: command })) {
        emulator.log(`💻 Sending command: ${command}`, 'info');
    }
}

function loadGame(filename) {
    if (emulator.sendMessage({ type: 'load_game', filename: filename })) {
        emulator.log(`🎮 Loading game: ${filename}`, 'info');
    }
}

function resetEmulator() {
    if (emulator.sendMessage({ type: 'reset' })) {
        emulator.log('🔄 Resetting emulator...', 'info');
    }
}

function toggleFullscreen() {
    const video = document.getElementById('videoPlayer');
    if (document.fullscreenElement) {
        document.exitFullscreen();
    } else {
        video.requestFullscreen().catch(err => {
            emulator.log(`❌ Fullscreen error: ${err.message}`, 'error');
        });
    }
}

// Initialize when page loads
document.addEventListener('DOMContentLoaded', () => {
    emulator = new SpectrumEmulator();
});
