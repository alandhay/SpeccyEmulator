# Quick Reference: Video Streaming Fixes

## 🚨 CRITICAL - DO NOT CHANGE THESE VALUES

### Backend Configuration (Python Server)
```python
# CRITICAL: These dimensions MUST match actual FUSE window
capture_size = "320x240"    # ✅ CORRECT - matches FUSE window
display_size = "320x240"    # ✅ CORRECT - Xvfb display size
output_size = "640x480"     # ✅ CORRECT - 2x scaled output

# WRONG VALUES (will cause screen cut-off):
# capture_size = "256x192"  # ❌ WRONG - causes missing pixels
```

### WebSocket Handler
```python
# ✅ CORRECT function signature:
async def handle_websocket(self, websocket):

# ❌ WRONG (causes TypeError):
# async def handle_websocket(self, websocket, path):
```

### Frontend CSS (Video Display)
```css
/* ✅ OPTIMAL video size for user experience */
.video-wrapper {
    max-width: 960px;        /* Perfect balance - not too big/small */
    aspect-ratio: 4/3;       /* Maintains ZX Spectrum proportions */
}

/* ✅ SCALED keyboard to match video */
.key {
    padding: 12px;           /* 50% larger than default */
    font-size: 1rem;         /* 25% larger than default */
    min-width: 40px;         /* 33% larger than default */
}
```

## 🔧 Production Files

### Current Production Version
- **File**: `server/emulator_server_framebuffer_fixed.py`
- **Docker**: `spectrum-emulator:framebuffer-capture-fixed`
- **Task Definition**: `spectrum-emulator-streaming:47`
- **Version**: `1.0.0-framebuffer-capture-fixed`

### Frontend Files
- **Main**: `web/index.html` (with optimized layout)
- **S3 Bucket**: `spectrum-emulator-web-dev-043309319786`
- **CloudFront**: `d112s3ps8xh739.cloudfront.net`

## 🧪 Testing Checklist

Before any changes, verify:
- [ ] Video shows full screen (no cut-off edges)
- [ ] WebSocket connects without TypeError
- [ ] Keyboard input works
- [ ] Mouse clicks register
- [ ] Video scales properly on different screens
- [ ] Both HLS and YouTube streams work

## 🚨 Common Mistakes to Avoid

1. **Changing capture dimensions** - Will cause screen cut-off
2. **Adding 'path' parameter to WebSocket handler** - Will cause TypeError
3. **Making video too large** - Reduces usability
4. **Not scaling keyboard proportionally** - Looks unbalanced
5. **Forgetting CloudFront cache invalidation** - Changes won't appear

## 📞 Emergency Rollback

If something breaks, immediately revert to:
```bash
# Rollback ECS service to working version
aws ecs update-service \
  --cluster spectrum-emulator-cluster-dev \
  --service spectrum-youtube-streaming \
  --task-definition spectrum-emulator-streaming:47
```

## 📚 Full Documentation

For complete details, see:
- `documentation/VIDEO_STREAMING_AND_LAYOUT_FIXES.md`
- `README.md` (v8 section)
