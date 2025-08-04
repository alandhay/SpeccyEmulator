/**
 * ZX Spectrum Emulator Local Test Client - Updated for new ports
 * =============================================================
 */

class LocalSpectrumEmulator {
    constructor() {
        this.websocket = null;
        this.hls = null;
        this.isConnected = false;
        
        // Configuration - updated ports to avoid conflicts
        this.websocketUrl = 'ws://localhost:8766';
        this.streamUrl = 'http://localhost:8001/stream/hls/stream.m3u8';
        this.healthUrl = 'http://localhost:8081/health';
        
        // DOM elements
        this.elements = {
            connectionStatus: document.getElementById('connection-status'),
            emulatorStatus: document.getElementById('emulator-status'),
            streamStatus: document.getElementById('stream-status'),
            videoPlayer: document.getElementById('video-player'),
            videoOverlay: document.getElementById('video-overlay'),
            streamUrl: document.getElementById('stream-url'),
            logOutput: document.getElementById('log-output'),
            
            // Buttons
            startEmulator: document.getElementById('start-emulator'),
            connectWebsocket: document.getElementById('connect-websocket'),
            testKey: document.getElementById('test-key'),
            getStatus: document.getElementById('get-status'),
            reloadStream: document.getElementById('reload-stream'),
            clearLogs: document.getElementById('clear-logs')
        };
        
        this.init();
    }
    
    init() {
        this.log('🚀 Initializing Local ZX Spectrum Emulator Client', 'info');
        
        // Update stream URL display
        this.elements.streamUrl.textContent = this.streamUrl;
        
        // Set up event listeners
        this.setupEventListeners();
        
        // Initialize video player
        this.initVideoPlayer();
        
        // Auto-connect on load
        setTimeout(() => this.connectWebSocket(), 1000);
        
        this.log('✅ Client initialized successfully', 'success');
    }
    
    setupEventListeners() {
        // Button event listeners
        this.elements.startEmulator.addEventListener('click', () => this.startEmulator());
        this.elements.connectWebsocket.addEventListener('click', () => this.connectWebSocket());
        this.elements.testKey.addEventListener('click', () => this.sendKey('SPACE'));
        this.elements.getStatus.addEventListener('click', () => this.getStatus());
        this.elements.reloadStream.addEventListener('click', () => this.reloadStream());
        this.elements.clearLogs.addEventListener('click', () => this.clearLogs());
        
        // Virtual keyboard
        document.querySelectorAll('.key').forEach(key => {
            key.addEventListener('click', (e) => {
                const keyValue = e.target.getAttribute('data-key');
                this.sendKey(keyValue);
                this.animateKeyPress(e.target);
            });
        });
        
        // Physical keyboard
        document.addEventListener('keydown', (e) => {
            this.handlePhysicalKey(e);
        });
        
        // Video overlay click
        this.elements.videoOverlay.addEventListener('click', () => {
            this.elements.videoOverlay.style.display = 'none';
        });
        
        // Video player events
        this.elements.videoPlayer.addEventListener('loadstart', () => {
            this.log('📺 Video loading started', 'info');
        });
        
        this.elements.videoPlayer.addEventListener('canplay', () => {
            this.log('📺 Video ready to play', 'success');
            this.updateStreamStatus('running');
        });
        
        this.elements.videoPlayer.addEventListener('error', (e) => {
            this.log(`📺 Video error: ${e.message}`, 'error');
            this.updateStreamStatus('stopped');
        });
    }
    
    initVideoPlayer() {
        if (Hls.isSupported()) {
            this.hls = new Hls({
                debug: false,
                enableWorker: true,
                lowLatencyMode: true,
                backBufferLength: 90
            });
            
            this.hls.loadSource(this.streamUrl);
            this.hls.attachMedia(this.elements.videoPlayer);
            
            this.hls.on(Hls.Events.MANIFEST_PARSED, () => {
                this.log('📺 HLS manifest loaded successfully', 'success');
                this.elements.videoPlayer.play().catch(e => {
                    this.log(`📺 Autoplay failed: ${e.message}`, 'warning');
                });
            });
            
            this.hls.on(Hls.Events.ERROR, (event, data) => {
                this.log(`📺 HLS error: ${data.type} - ${data.details}`, 'error');
                if (data.fatal) {
                    this.updateStreamStatus('stopped');
                }
            });
            
        } else if (this.elements.videoPlayer.canPlayType('application/vnd.apple.mpegurl')) {
            // Safari native HLS support
            this.elements.videoPlayer.src = this.streamUrl;
            this.log('📺 Using native HLS support', 'info');
        } else {
            this.log('📺 HLS not supported in this browser', 'error');
        }
    }
    
    connectWebSocket() {
        if (this.websocket && this.websocket.readyState === WebSocket.OPEN) {
            this.log('🔌 WebSocket already connected', 'warning');
            return;
        }
        
        this.log(`🔌 Connecting to WebSocket: ${this.websocketUrl}`, 'info');
        
        try {
            this.websocket = new WebSocket(this.websocketUrl);
            
            this.websocket.onopen = () => {
                this.log('🔌 WebSocket connected successfully', 'success');
                this.isConnected = true;
                this.updateConnectionStatus('connected');
            };
            
            this.websocket.onmessage = (event) => {
                try {
                    const data = JSON.parse(event.data);
                    this.handleWebSocketMessage(data);
                } catch (e) {
                    this.log(`🔌 Invalid JSON received: ${event.data}`, 'error');
                }
            };
            
            this.websocket.onclose = () => {
                this.log('🔌 WebSocket connection closed', 'warning');
                this.isConnected = false;
                this.updateConnectionStatus('disconnected');
            };
            
            this.websocket.onerror = (error) => {
                this.log(`🔌 WebSocket error: ${error}`, 'error');
                this.isConnected = false;
                this.updateConnectionStatus('disconnected');
            };
            
        } catch (error) {
            this.log(`🔌 Failed to create WebSocket: ${error}`, 'error');
        }
    }
    
    handleWebSocketMessage(data) {
        this.log(`📨 Received: ${JSON.stringify(data)}`, 'info');
        
        switch (data.type) {
            case 'connected':
                this.updateEmulatorStatus(data.emulator_running ? 'running' : 'stopped');
                this.updateStreamStatus(data.hls_streaming ? 'running' : 'stopped');
                break;
                
            case 'key_response':
                const status = data.success ? '✅' : '❌';
                this.log(`⌨️ Key '${data.key}' ${status}`, data.success ? 'success' : 'error');
                break;
                
            case 'emulator_status':
                this.updateEmulatorStatus(data.running ? 'running' : 'stopped');
                this.log(`🎮 ${data.message}`, data.running ? 'success' : 'error');
                break;
                
            case 'status_response':
                this.updateEmulatorStatus(data.emulator_running ? 'running' : 'stopped');
                this.updateStreamStatus(data.hls_streaming ? 'running' : 'stopped');
                this.log(`📊 Status updated`, 'info');
                break;
        }
    }
    
    sendWebSocketMessage(message) {
        if (!this.isConnected || !this.websocket) {
            this.log('🔌 WebSocket not connected', 'error');
            return false;
        }
        
        try {
            this.websocket.send(JSON.stringify(message));
            this.log(`📤 Sent: ${JSON.stringify(message)}`, 'info');
            return true;
        } catch (error) {
            this.log(`📤 Failed to send message: ${error}`, 'error');
            return false;
        }
    }
    
    startEmulator() {
        this.log('🎮 Starting emulator...', 'info');
        this.sendWebSocketMessage({ type: 'start_emulator' });
    }
    
    sendKey(key) {
        this.log(`⌨️ Sending key: ${key}`, 'info');
        this.sendWebSocketMessage({ type: 'key_press', key: key });
    }
    
    getStatus() {
        this.log('📊 Requesting status...', 'info');
        this.sendWebSocketMessage({ type: 'status' });
    }
    
    reloadStream() {
        this.log('🔄 Reloading video stream...', 'info');
        
        if (this.hls) {
            this.hls.destroy();
        }
        
        // Reinitialize video player
        setTimeout(() => {
            this.initVideoPlayer();
        }, 1000);
    }
    
    handlePhysicalKey(event) {
        // Map common keys
        const keyMap = {
            'Space': 'SPACE',
            'Enter': 'ENTER',
            'Escape': 'ESCAPE',
            'Backspace': 'BACKSPACE',
            'ArrowUp': 'UP',
            'ArrowDown': 'DOWN',
            'ArrowLeft': 'LEFT',
            'ArrowRight': 'RIGHT'
        };
        
        let key = keyMap[event.code] || event.key.toUpperCase();
        
        // Only send alphanumeric and special keys
        if (/^[A-Z0-9]$/.test(key) || keyMap[event.code]) {
            event.preventDefault();
            this.sendKey(key);
            
            // Animate corresponding virtual key if it exists
            const virtualKey = document.querySelector(`[data-key="${key}"]`);
            if (virtualKey) {
                this.animateKeyPress(virtualKey);
            }
        }
    }
    
    animateKeyPress(keyElement) {
        keyElement.classList.add('pressed');
        setTimeout(() => {
            keyElement.classList.remove('pressed');
        }, 150);
    }
    
    updateConnectionStatus(status) {
        const element = this.elements.connectionStatus;
        element.className = `status-${status}`;
        element.textContent = status === 'connected' ? 'Connected' : 'Disconnected';
    }
    
    updateEmulatorStatus(status) {
        const element = this.elements.emulatorStatus;
        element.className = `status-${status}`;
        element.textContent = status === 'running' ? 'Emulator Running' : 'Emulator Stopped';
    }
    
    updateStreamStatus(status) {
        const element = this.elements.streamStatus;
        element.className = `status-${status}`;
        element.textContent = status === 'running' ? 'Stream Active' : 'Stream Stopped';
    }
    
    log(message, type = 'info') {
        const timestamp = new Date().toLocaleTimeString();
        const logEntry = document.createElement('div');
        logEntry.className = `log-entry log-${type}`;
        logEntry.textContent = `[${timestamp}] ${message}`;
        
        this.elements.logOutput.appendChild(logEntry);
        this.elements.logOutput.scrollTop = this.elements.logOutput.scrollHeight;
        
        // Also log to console
        console.log(`[${type.toUpperCase()}] ${message}`);
    }
    
    clearLogs() {
        this.elements.logOutput.innerHTML = '';
        this.log('🗑️ Logs cleared', 'info');
    }
}

// Initialize the emulator client when the page loads
document.addEventListener('DOMContentLoaded', () => {
    window.spectrumEmulator = new LocalSpectrumEmulator();
});
