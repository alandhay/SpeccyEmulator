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
        const wsUrl = 'wss://d112s3ps8xh739.cloudfront.net/ws/';
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
            key.addEventListener('click', () => {
                const keyValue = key.dataset.key;
                this.sendKey(keyValue);
            });
        });
    }

    setupPhysicalKeyboard() {
        document.addEventListener('keydown', (event) => {
            if (event.target.tagName === 'INPUT' || event.target.tagName === 'TEXTAREA') {
                return; // Don't intercept when typing in inputs
            }
            
            event.preventDefault();
            let key = event.key.toUpperCase();
            
            // Map special keys to ZX Spectrum equivalents
            const keyMap = {
                ' ': 'SPACE',
                'ENTER': 'ENTER',
                'SHIFT': 'SHIFT',
                'CONTROL': 'SYMBOL',
                'ALT': 'SYMBOL',
                'BACKSPACE': 'DELETE',
                'DELETE': 'DELETE',
                'ARROWUP': 'UP',
                'ARROWDOWN': 'DOWN',
                'ARROWLEFT': 'LEFT',
                'ARROWRIGHT': 'RIGHT'
            };
            
            key = keyMap[key] || key;
            
            // Only send valid ZX Spectrum keys
            const validKeys = ['1','2','3','4','5','6','7','8','9','0',
                             'Q','W','E','R','T','Y','U','I','O','P',
                             'A','S','D','F','G','H','J','K','L',
                             'Z','X','C','V','B','N','M',
                             'SPACE','ENTER','SHIFT','SYMBOL','DELETE',
                             'UP','DOWN','LEFT','RIGHT'];
            
            if (validKeys.includes(key)) {
                this.sendKey(key);
            }
        });
    }

    sendKey(key) {
        if (this.sendMessage({ type: 'key_press', key: key })) {
            this.log(`⌨️ Key pressed: ${key}`, 'info');
            
            // Visual feedback
            const keyElement = document.querySelector(`[data-key="${key}"]`);
            if (keyElement) {
                keyElement.style.transform = 'translateY(2px)';
                keyElement.style.background = 'linear-gradient(145deg, #00ff00, #00cc00)';
                keyElement.style.color = '#000';
                setTimeout(() => {
                    keyElement.style.transform = '';
                    keyElement.style.background = '';
                    keyElement.style.color = '';
                }, 150);
            }
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
    emulator.log('📸 Screenshot feature coming soon...', 'info');
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
