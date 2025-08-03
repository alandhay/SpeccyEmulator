class SpectrumEmulator {
    constructor() {
        this.ws = null;
        this.hls = null;
        this.connected = false;
        this.emulatorRunning = false;
        this.reconnectAttempts = 0;
        this.maxReconnectAttempts = 5;
        
        // Track pressed keys to prevent duplicates
        this.pressedKeys = new Set();
        this.virtualKeyPressed = new Set();
        
        this.init();
    }

    init() {
        this.setupHLS();
        this.connectWebSocket();
        this.setupSimpleKeyboard();
        this.setupPhysicalKeyboard();
        this.setupMouse();
        this.log('🎮 ZX Spectrum Emulator Interface Ready', 'info');
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
                liveSyncDurationCount: 3
            });
            
            this.hls.loadSource(streamUrl);
            this.hls.attachMedia(video);
            
            this.hls.on(Hls.Events.MANIFEST_PARSED, () => {
                this.log('📺 Stream connected successfully!', 'success');
                video.play().catch(e => {
                    this.log('⚠️ Click video to start playback', 'info');
                });
            });

            this.hls.on(Hls.Events.ERROR, (event, data) => {
                if (data.fatal) {
                    this.log(`❌ Stream error: ${data.details}`, 'error');
                    setTimeout(() => this.setupHLS(), 3000);
                }
            });
        }
    }

    connectWebSocket() {
        const wsUrl = CONFIG.WEBSOCKET_URL;
        this.log(`🔌 Connecting to server at ${wsUrl}...`, 'info');

        try {
            this.ws = new WebSocket(wsUrl);
            
            this.ws.onopen = () => {
                this.connected = true;
                this.reconnectAttempts = 0;
                this.updateConnectionStatus(true);
                this.log('✅ Connected to emulator server!', 'success');
                
                // Check emulator status
                setTimeout(() => {
                    this.sendMessage({ type: 'status' });
                }, 1000);
            };

            this.ws.onmessage = (event) => {
                try {
                    const data = JSON.parse(event.data);
                    this.handleMessage(data);
                } catch (e) {
                    this.log(`📨 Raw message: ${event.data}`, 'info');
                }
            };

            this.ws.onclose = () => {
                this.connected = false;
                this.updateConnectionStatus(false);
                this.log('🔌 Connection closed', 'error');
                this.attemptReconnect();
            };

            this.ws.onerror = (error) => {
                this.log('❌ WebSocket error', 'error');
            };
        } catch (error) {
            this.log(`❌ Connection failed: ${error.message}`, 'error');
            this.attemptReconnect();
        }
    }

    attemptReconnect() {
        if (this.reconnectAttempts < this.maxReconnectAttempts) {
            this.reconnectAttempts++;
            const delay = Math.min(1000 * Math.pow(2, this.reconnectAttempts), 10000);
            this.log(`🔄 Reconnecting in ${delay/1000}s...`, 'info');
            setTimeout(() => this.connectWebSocket(), delay);
        }
    }

    handleMessage(data) {
        switch (data.type) {
            case 'connected':
                this.log(`🎬 Server ready: ${data.message || 'Connected'}`, 'success');
                if (data.emulator_running) {
                    this.emulatorRunning = true;
                    this.updateEmulatorStatus(true);
                    this.log('🎮 Emulator is running!', 'success');
                }
                break;
            
            case 'emulator_status':
            case 'status_response':
                this.emulatorRunning = data.running || data.emulator_running;
                this.updateEmulatorStatus(this.emulatorRunning);
                this.log(`📊 Emulator: ${this.emulatorRunning ? 'Running' : 'Stopped'}`, 'info');
                break;
            
            case 'key_response':
                // Handle server response - server sends 'processed' field, not 'success'
                const status = data.processed ? '✅' : '❌';
                const action = data.action || 'action';
                const key = data.key || 'unknown';
                const message = data.message || '';
                
                if (data.processed) {
                    this.log(`${status} Key ${action}: ${key}`, 'success');
                } else {
                    this.log(`${status} Key ${action} failed: ${key} - ${message}`, 'error');
                }
                break;
            
            case 'error':
                this.log(`❌ Error: ${data.message}`, 'error');
                break;
            
            default:
                // Handle any other message types
                this.log(`📨 ${JSON.stringify(data)}`, 'info');
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

    // SIMPLIFIED VIRTUAL KEYBOARD - Click only, no hover, no complex state
    setupSimpleKeyboard() {
        document.querySelectorAll('.key').forEach(key => {
            // Single click handler - press and release immediately
            key.addEventListener('click', (e) => {
                e.preventDefault();
                e.stopPropagation();
                
                const keyValue = key.dataset.key;
                if (!keyValue) return;
                
                // Visual feedback
                this.flashKey(key);
                
                // Send key press immediately followed by release
                this.sendKeyPress(keyValue);
                
                // Auto-release after short delay
                setTimeout(() => {
                    this.sendKeyRelease(keyValue);
                }, 100);
            });
            
            // Prevent other mouse events from interfering
            key.addEventListener('mousedown', (e) => e.preventDefault());
            key.addEventListener('mouseup', (e) => e.preventDefault());
            key.addEventListener('mouseleave', (e) => e.preventDefault());
        });
        
        this.log('⌨️ Virtual keyboard ready (click-only mode)', 'info');
    }

    // Simple visual feedback for key press
    flashKey(keyElement) {
        keyElement.style.transform = 'translateY(2px)';
        keyElement.style.background = 'linear-gradient(145deg, #00ff00, #00cc00)';
        keyElement.style.color = '#000';
        
        setTimeout(() => {
            keyElement.style.transform = '';
            keyElement.style.background = '';
            keyElement.style.color = '';
        }, 150);
    }

    setupPhysicalKeyboard() {
        document.addEventListener('keydown', (event) => {
            if (event.target.tagName === 'INPUT' || event.target.tagName === 'TEXTAREA') {
                return;
            }
            
            if (this.pressedKeys.has(event.code)) {
                event.preventDefault();
                return;
            }
            
            event.preventDefault();
            this.pressedKeys.add(event.code);
            
            const key = this.mapPhysicalKey(event);
            if (key) {
                this.sendKeyPress(key);
            }
        });
        
        document.addEventListener('keyup', (event) => {
            if (event.target.tagName === 'INPUT' || event.target.tagName === 'TEXTAREA') {
                return;
            }
            
            event.preventDefault();
            this.pressedKeys.delete(event.code);
            
            const key = this.mapPhysicalKey(event);
            if (key) {
                this.sendKeyRelease(key);
            }
        });
        
        window.addEventListener('blur', () => {
            this.pressedKeys.clear();
        });
    }
    
    mapPhysicalKey(event) {
        const keyMap = {
            'Digit1': '1', 'Digit2': '2', 'Digit3': '3', 'Digit4': '4', 'Digit5': '5',
            'Digit6': '6', 'Digit7': '7', 'Digit8': '8', 'Digit9': '9', 'Digit0': '0',
            'KeyQ': 'Q', 'KeyW': 'W', 'KeyE': 'E', 'KeyR': 'R', 'KeyT': 'T',
            'KeyY': 'Y', 'KeyU': 'U', 'KeyI': 'I', 'KeyO': 'O', 'KeyP': 'P',
            'KeyA': 'A', 'KeyS': 'S', 'KeyD': 'D', 'KeyF': 'F', 'KeyG': 'G',
            'KeyH': 'H', 'KeyJ': 'J', 'KeyK': 'K', 'KeyL': 'L',
            'KeyZ': 'Z', 'KeyX': 'X', 'KeyC': 'C', 'KeyV': 'V', 'KeyB': 'B',
            'KeyN': 'N', 'KeyM': 'M',
            'Space': 'SPACE',
            'Enter': 'ENTER',
            'ShiftLeft': 'SHIFT', 'ShiftRight': 'SHIFT',
            'Backspace': 'DELETE',
            'ArrowUp': 'Q', 'ArrowLeft': 'A', 'ArrowDown': 'O', 'ArrowRight': 'P'
        };
        
        return keyMap[event.code] || null;
    }

    setupMouse() {
        const video = document.getElementById('videoPlayer');
        if (!video) return;

        video.addEventListener('click', (e) => {
            e.preventDefault();
            const rect = video.getBoundingClientRect();
            const x = ((e.clientX - rect.left) / rect.width) * 256;
            const y = ((e.clientY - rect.top) / rect.height) * 192;
            this.sendMouseClick('left', x, y);
        });

        video.addEventListener('contextmenu', (e) => {
            e.preventDefault();
            const rect = video.getBoundingClientRect();
            const x = ((e.clientX - rect.left) / rect.width) * 256;
            const y = ((e.clientY - rect.top) / rect.height) * 192;
            this.sendMouseClick('right', x, y);
        });

        video.style.cursor = 'crosshair';
        this.log('🖱️ Mouse support enabled', 'info');
    }

    // Simplified key sending - use the message format the server expects
    sendKeyPress(key) {
        const message = { 
            type: 'key_press',  // Server expects key_press with action field
            key: key,
            action: 'press'
        };
        
        if (this.sendMessage(message)) {
            this.log(`⌨️ Key press: ${key}`, 'info');
        }
    }

    sendKeyRelease(key) {
        const message = { 
            type: 'key_press',  // Server expects key_press with action field
            key: key,
            action: 'release'
        };
        
        if (this.sendMessage(message)) {
            this.log(`⌨️ Key release: ${key}`, 'info');
        }
    }

    sendMouseClick(button, x, y) {
        const message = { 
            type: 'mouse_click', 
            button: button,
            x: Math.round(x),
            y: Math.round(y)
        };
        
        if (this.sendMessage(message)) {
            this.log(`🖱️ Mouse ${button} click at (${Math.round(x)},${Math.round(y)})`, 'info');
        }
    }

    updateConnectionStatus(connected) {
        const status = document.getElementById('connectionStatus');
        if (connected) {
            status.textContent = '⚡ Connected';
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
            status.textContent = '🎮 Running';
            status.className = 'status-item status-connected';
            if (startBtn) startBtn.disabled = true;
            if (stopBtn) stopBtn.disabled = false;
        } else {
            status.textContent = '🎯 Ready';
            status.className = 'status-item';
            if (startBtn) startBtn.disabled = false;
            if (stopBtn) stopBtn.disabled = true;
        }
    }

    log(message, type = 'info') {
        const logContent = document.getElementById('logContent');
        if (!logContent) return;
        
        const timestamp = new Date().toLocaleTimeString();
        const entry = document.createElement('div');
        entry.className = `log-entry ${type}`;
        entry.textContent = `[${timestamp}] ${message}`;
        
        logContent.appendChild(entry);
        logContent.scrollTop = logContent.scrollHeight;
        
        // Keep only last 30 entries
        while (logContent.children.length > 30) {
            logContent.removeChild(logContent.firstChild);
        }
    }
}

// Global functions for buttons
let emulator;

function startEmulator() {
    if (emulator && emulator.sendMessage({ type: 'start_emulator' })) {
        emulator.log('🚀 Starting emulator...', 'info');
    }
}

function stopEmulator() {
    if (emulator && emulator.sendMessage({ type: 'stop_emulator' })) {
        emulator.log('⏹️ Stopping emulator...', 'info');
    }
}

function requestStatus() {
    if (emulator && emulator.sendMessage({ type: 'status' })) {
        emulator.log('📊 Requesting status...', 'info');
    }
}

function takeScreenshot() {
    if (emulator && emulator.sendMessage({ type: 'screenshot' })) {
        emulator.log('📸 Taking screenshot...', 'info');
    }
}

function resetEmulator() {
    if (emulator && emulator.sendMessage({ type: 'reset' })) {
        emulator.log('🔄 Resetting emulator...', 'info');
    }
}

function toggleFullscreen() {
    const video = document.getElementById('videoPlayer');
    if (document.fullscreenElement) {
        document.exitFullscreen();
    } else {
        video.requestFullscreen().catch(err => {
            if (emulator) emulator.log(`❌ Fullscreen error: ${err.message}`, 'error');
        });
    }
}

// Initialize when page loads
document.addEventListener('DOMContentLoaded', () => {
    emulator = new SpectrumEmulator();
});
