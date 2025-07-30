/**
 * ZX Spectrum Emulator Web Client
 * Handles WebSocket communication and user interface
 */

class SpectrumEmulatorClient {
    constructor() {
        this.websocket = null;
        this.isConnected = false;
        this.emulatorRunning = false;
        this.videoPlayer = null;
        this.reconnectAttempts = 0;
        this.maxReconnectAttempts = 5;
        
        // Configuration - will be overridden by config.js if available
        this.config = {
            websocket_url: 'ws://localhost:8765',
            api_base_url: 'http://localhost:8080',
            stream_base_url: 'http://localhost:8080/stream',
            cloudfront_domain: null,
            environment: 'local'
        };
        
        // Override with AWS config if available
        if (typeof window.AWS_CONFIG !== 'undefined') {
            this.config = { ...this.config, ...window.AWS_CONFIG };
        }
        
        this.init();
    }
    
    init() {
        this.setupEventListeners();
        this.setupVideoPlayer();
        this.connect();
        this.loadAvailableGames();
    }
    
    setupEventListeners() {
        // Control buttons
        document.getElementById('start-btn').addEventListener('click', () => this.startEmulator());
        document.getElementById('stop-btn').addEventListener('click', () => this.stopEmulator());
        document.getElementById('screenshot-btn').addEventListener('click', () => this.takeScreenshot());
        document.getElementById('fullscreen-btn').addEventListener('click', () => this.toggleFullscreen());
        
        // Game loading
        document.getElementById('load-game-btn').addEventListener('click', () => this.loadGame());
        document.getElementById('upload-btn').addEventListener('click', () => this.uploadGame());
        document.getElementById('game-upload').addEventListener('change', (e) => this.handleGameUpload(e));
        
        // Keyboard events
        this.setupKeyboardEvents();
        
        // Physical keyboard support
        document.addEventListener('keydown', (e) => this.handlePhysicalKeyboard(e));
        document.addEventListener('keyup', (e) => this.handlePhysicalKeyboardUp(e));
        
        // Fullscreen events
        document.addEventListener('fullscreenchange', () => this.handleFullscreenChange());
        document.addEventListener('webkitfullscreenchange', () => this.handleFullscreenChange());
        document.addEventListener('mozfullscreenchange', () => this.handleFullscreenChange());
        document.addEventListener('MSFullscreenChange', () => this.handleFullscreenChange());
    }
    
    setupVideoPlayer() {
        const video = document.getElementById('emulator-video');
        const streamUrl = `${this.config.stream_base_url}/hls/stream.m3u8`;
        
        // Check if HLS.js is supported
        if (Hls.isSupported()) {
            this.videoPlayer = new Hls({
                enableWorker: true,
                lowLatencyMode: true,
                backBufferLength: 90
            });
            
            this.videoPlayer.loadSource(streamUrl);
            this.videoPlayer.attachMedia(video);
            
            this.videoPlayer.on(Hls.Events.MANIFEST_PARSED, () => {
                console.log('HLS manifest parsed, starting playback');
            });
            
            this.videoPlayer.on(Hls.Events.ERROR, (event, data) => {
                console.error('HLS error:', data);
                if (data.fatal) {
                    this.handleVideoError();
                }
            });
        } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
            // Native HLS support (Safari)
            video.src = streamUrl;
        } else {
            console.error('HLS not supported');
            this.showMessage('Video streaming not supported in this browser', 'error');
        }
    }
    
    setupKeyboardEvents() {
        const keys = document.querySelectorAll('.key');
        
        keys.forEach(key => {
            key.addEventListener('mousedown', (e) => {
                e.preventDefault();
                const keyValue = key.getAttribute('data-key');
                this.sendKey(keyValue);
                this.animateKey(key);
            });
            
            key.addEventListener('touchstart', (e) => {
                e.preventDefault();
                const keyValue = key.getAttribute('data-key');
                this.sendKey(keyValue);
                this.animateKey(key);
            });
        });
    }
    
    connect() {
        try {
            // Use WebSocket URL from config
            const wsUrl = this.config.websocket_url;
            console.log('Connecting to WebSocket:', wsUrl);
            
            // Create WebSocket connection with specific options for CloudFront
            this.websocket = new WebSocket(wsUrl);
            
            // Set a shorter timeout for connection attempts
            const connectionTimeout = setTimeout(() => {
                if (this.websocket.readyState === WebSocket.CONNECTING) {
                    console.log('WebSocket connection timeout, closing...');
                    this.websocket.close();
                }
            }, 10000); // 10 second timeout
            
            this.websocket.onopen = () => {
                console.log('Connected to emulator server');
                clearTimeout(connectionTimeout);
                this.isConnected = true;
                this.reconnectAttempts = 0;
                this.updateConnectionStatus('connected');
                this.requestStatus();
            };
            
            this.websocket.onmessage = (event) => {
                this.handleMessage(JSON.parse(event.data));
            };
            
            this.websocket.onclose = (event) => {
                console.log('Disconnected from emulator server', event.code, event.reason);
                clearTimeout(connectionTimeout);
                this.isConnected = false;
                this.updateConnectionStatus('disconnected');
                
                // Don't auto-reconnect if it was a clean close
                if (event.code !== 1000) {
                    this.attemptReconnect();
                }
            };
            
            this.websocket.onerror = (error) => {
                console.error('WebSocket error:', error);
                clearTimeout(connectionTimeout);
                this.showMessage('Connection error - trying alternative connection method', 'error');
                
                // Try alternative connection method
                this.tryAlternativeConnection();
            };
            
        } catch (error) {
            console.error('Failed to connect:', error);
            this.updateConnectionStatus('disconnected');
            this.attemptReconnect();
        }
    }
    
    tryAlternativeConnection() {
        // If the primary WebSocket fails, try without the trailing slash
        if (this.config.websocket_url.endsWith('/')) {
            console.log('Trying alternative WebSocket URL without trailing slash');
            const altUrl = this.config.websocket_url.slice(0, -1);
            
            try {
                this.websocket = new WebSocket(altUrl);
                
                this.websocket.onopen = () => {
                    console.log('Connected to emulator server (alternative URL)');
                    this.isConnected = true;
                    this.reconnectAttempts = 0;
                    this.updateConnectionStatus('connected');
                    this.requestStatus();
                };
                
                this.websocket.onmessage = (event) => {
                    this.handleMessage(JSON.parse(event.data));
                };
                
                this.websocket.onclose = (event) => {
                    console.log('Disconnected from emulator server (alternative)');
                    this.isConnected = false;
                    this.updateConnectionStatus('disconnected');
                    this.attemptReconnect();
                };
                
                this.websocket.onerror = (error) => {
                    console.error('Alternative WebSocket error:', error);
                    this.showMessage('Connection failed - server may be starting up', 'error');
                    this.attemptReconnect();
                };
                
            } catch (error) {
                console.error('Alternative connection failed:', error);
                this.attemptReconnect();
            }
        } else {
            this.attemptReconnect();
        }
    }
    
    attemptReconnect() {
        if (this.reconnectAttempts < this.maxReconnectAttempts) {
            this.reconnectAttempts++;
            console.log(`Attempting to reconnect (${this.reconnectAttempts}/${this.maxReconnectAttempts})...`);
            setTimeout(() => this.connect(), 2000 * this.reconnectAttempts);
        } else {
            this.showMessage('Failed to connect to emulator server', 'error');
        }
    }
    
    handleMessage(message) {
        console.log('Received message:', message);
        
        switch (message.type) {
            case 'connected':
                this.showMessage(message.message, 'success');
                break;
                
            case 'emulator_status':
                this.emulatorRunning = message.running;
                this.updateEmulatorStatus(message.running);
                this.showMessage(message.message, message.running ? 'success' : 'info');
                break;
                
            case 'game_loaded':
                if (message.success) {
                    this.showMessage(`Game loaded: ${message.game}`, 'success');
                    this.updateGameStatus(message.game);
                } else {
                    this.showMessage('Failed to load game', 'error');
                }
                break;
                
            case 'key_pressed':
                // Visual feedback for key press
                this.highlightPhysicalKey(message.key);
                break;
                
            case 'screenshot_taken':
                if (message.path) {
                    this.showMessage('Screenshot saved', 'success');
                } else {
                    this.showMessage('Failed to take screenshot', 'error');
                }
                break;
                
            case 'status':
                this.emulatorRunning = message.emulator_running;
                this.updateEmulatorStatus(message.emulator_running);
                if (message.current_game) {
                    this.updateGameStatus(message.current_game);
                }
                break;
                
            default:
                console.log('Unknown message type:', message.type);
        }
    }
    
    sendMessage(message) {
        if (this.isConnected && this.websocket.readyState === WebSocket.OPEN) {
            this.websocket.send(JSON.stringify(message));
        } else {
            this.showMessage('Not connected to server', 'error');
        }
    }
    
    startEmulator() {
        this.sendMessage({ type: 'start_emulator' });
        this.showLoadingScreen(false);
    }
    
    stopEmulator() {
        this.sendMessage({ type: 'stop_emulator' });
        this.showLoadingScreen(true);
    }
    
    loadGame() {
        const gameSelect = document.getElementById('game-select');
        const selectedGame = gameSelect.value;
        
        if (selectedGame) {
            this.sendMessage({ 
                type: 'load_game', 
                game: selectedGame 
            });
        } else {
            this.showMessage('Please select a game', 'warning');
        }
    }
    
    takeScreenshot() {
        this.sendMessage({ type: 'screenshot' });
    }
    
    sendKey(key) {
        if (this.emulatorRunning) {
            this.sendMessage({ 
                type: 'key_press', 
                key: key 
            });
        }
    }
    
    requestStatus() {
        this.sendMessage({ type: 'get_status' });
    }
    
    // UI Update Methods
    updateConnectionStatus(status) {
        const statusElement = document.getElementById('connection-status');
        statusElement.textContent = status === 'connected' ? 'Connected' : 'Disconnected';
        statusElement.className = `status ${status}`;
    }
    
    updateEmulatorStatus(running) {
        const statusElement = document.getElementById('emulator-status');
        statusElement.textContent = running ? 'Emulator Running' : 'Emulator Stopped';
        statusElement.className = `status ${running ? 'running' : 'stopped'}`;
        
        // Update button states
        document.getElementById('start-btn').disabled = running;
        document.getElementById('stop-btn').disabled = !running;
        document.getElementById('screenshot-btn').disabled = !running;
        document.getElementById('load-game-btn').disabled = !running;
    }
    
    updateGameStatus(gameName) {
        const statusElement = document.getElementById('game-status');
        statusElement.textContent = gameName ? `Game: ${gameName}` : 'No Game Loaded';
    }
    
    showLoadingScreen(show) {
        const loadingScreen = document.getElementById('loading-screen');
        loadingScreen.style.display = show ? 'flex' : 'none';
    }
    
    showMessage(message, type = 'info') {
        // Create a simple toast notification
        const toast = document.createElement('div');
        toast.className = `toast toast-${type}`;
        toast.textContent = message;
        toast.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            padding: 10px 20px;
            border-radius: 5px;
            color: white;
            font-weight: bold;
            z-index: 1000;
            opacity: 0;
            transition: opacity 0.3s ease;
        `;
        
        // Set background color based on type
        const colors = {
            success: '#4CAF50',
            error: '#f44336',
            warning: '#ff9800',
            info: '#2196F3'
        };
        toast.style.backgroundColor = colors[type] || colors.info;
        
        document.body.appendChild(toast);
        
        // Animate in
        setTimeout(() => toast.style.opacity = '1', 10);
        
        // Remove after 3 seconds
        setTimeout(() => {
            toast.style.opacity = '0';
            setTimeout(() => document.body.removeChild(toast), 300);
        }, 3000);
    }
    
    animateKey(keyElement) {
        keyElement.classList.add('pressed');
        setTimeout(() => keyElement.classList.remove('pressed'), 100);
    }
    
    highlightPhysicalKey(key) {
        const keyElement = document.querySelector(`[data-key="${key}"]`);
        if (keyElement) {
            this.animateKey(keyElement);
        }
    }
    
    // Physical Keyboard Handling
    handlePhysicalKeyboard(event) {
        if (!this.emulatorRunning) return;
        
        // Prevent default browser behavior for emulator keys
        const key = event.key.toLowerCase();
        const spectrumKeys = [
            '1', '2', '3', '4', '5', '6', '7', '8', '9', '0',
            'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p',
            'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l',
            'z', 'x', 'c', 'v', 'b', 'n', 'm',
            'enter', 'shift', ' '
        ];
        
        if (spectrumKeys.includes(key) || key === ' ') {
            event.preventDefault();
            const mappedKey = key === ' ' ? 'space' : key;
            this.sendKey(mappedKey);
            this.highlightPhysicalKey(mappedKey);
        }
        
        // Handle special keys
        if (event.key === 'F11') {
            event.preventDefault();
            this.toggleFullscreen();
        }
    }
    
    handlePhysicalKeyboardUp(event) {
        // Handle key release if needed
    }
    
    // Fullscreen functionality
    toggleFullscreen() {
        const screenContainer = document.querySelector('.spectrum-screen');
        
        if (!document.fullscreenElement) {
            if (screenContainer.requestFullscreen) {
                screenContainer.requestFullscreen();
            } else if (screenContainer.webkitRequestFullscreen) {
                screenContainer.webkitRequestFullscreen();
            } else if (screenContainer.mozRequestFullScreen) {
                screenContainer.mozRequestFullScreen();
            } else if (screenContainer.msRequestFullscreen) {
                screenContainer.msRequestFullscreen();
            }
        } else {
            if (document.exitFullscreen) {
                document.exitFullscreen();
            } else if (document.webkitExitFullscreen) {
                document.webkitExitFullscreen();
            } else if (document.mozCancelFullScreen) {
                document.mozCancelFullScreen();
            } else if (document.msExitFullscreen) {
                document.msExitFullscreen();
            }
        }
    }
    
    handleFullscreenChange() {
        const screenContainer = document.querySelector('.spectrum-screen');
        const isFullscreen = document.fullscreenElement === screenContainer;
        
        if (isFullscreen) {
            screenContainer.classList.add('fullscreen');
        } else {
            screenContainer.classList.remove('fullscreen');
        }
    }
    
    // Game management
    loadAvailableGames() {
        // This would typically fetch from the server
        // For now, we'll add some common game types
        const gameSelect = document.getElementById('game-select');
        const commonGames = [
            'manic_miner.tzx',
            'jet_set_willy.tzx',
            'chuckie_egg.tap',
            'horace_goes_skiing.tap'
        ];
        
        commonGames.forEach(game => {
            const option = document.createElement('option');
            option.value = game;
            option.textContent = game.replace(/\.(tzx|tap)$/, '').replace(/_/g, ' ').toUpperCase();
            gameSelect.appendChild(option);
        });
    }
    
    uploadGame() {
        document.getElementById('game-upload').click();
    }
    
    handleGameUpload(event) {
        const file = event.target.files[0];
        if (file) {
            // This would upload the file to the server
            // For now, just show a message
            this.showMessage(`Game upload: ${file.name}`, 'info');
        }
    }
    
    handleVideoError() {
        console.error('Video streaming error');
        this.showMessage('Video streaming error - check if emulator is running', 'error');
    }
}

// Initialize the emulator client when the page loads
document.addEventListener('DOMContentLoaded', () => {
    window.spectrumEmulator = new SpectrumEmulatorClient();
});

// Handle page visibility changes
document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
        // Page is hidden, pause video if needed
        const video = document.getElementById('emulator-video');
        if (video && !video.paused) {
            video.pause();
        }
    } else {
        // Page is visible, resume video
        const video = document.getElementById('emulator-video');
        if (video && video.paused) {
            video.play();
        }
    }
});
