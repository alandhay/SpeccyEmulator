// Configuration for ZX Spectrum Emulator
const CONFIG = {
    // WebSocket connection - using new RTMP-enabled task
    WEBSOCKET_URL: 'ws://54.164.181.209:8765',
    
    // Video stream - direct from container (no S3 dependency)
    STREAM_URL: 'http://54.164.181.209:8080/stream/stream.m3u8',
    
    // Connection settings
    RECONNECT_INTERVAL: 3000,
    MAX_RECONNECT_ATTEMPTS: 10,
    
    // Video settings
    VIDEO_AUTOPLAY: true,
    VIDEO_MUTED: true,
    
    // Debug mode
    DEBUG: true
};

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = CONFIG;
}
