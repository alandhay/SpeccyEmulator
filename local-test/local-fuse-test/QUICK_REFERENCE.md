# 🚀 QUICK REFERENCE - GOLDEN FUSE STREAMING

## ⭐ **GOLDEN REFERENCE COMMAND**

```bash
# Navigate to directory
cd /home/ubuntu/workspace/SpeccyEmulator/local-test/local-fuse-test

# Start streaming with optimal settings (RECOMMENDED)
./stream_minimal_adjustable_scale.sh

# Or with custom scaling
./stream_minimal_adjustable_scale.sh 85   # Smaller (1.7x)
./stream_minimal_adjustable_scale.sh 90   # Default (1.8x) - OPTIMAL
./stream_minimal_adjustable_scale.sh 95   # Larger (1.9x)
```

## 🎯 **Quick Commands**

### **Start Streaming**
```bash
# Default optimal scaling (90% = 1.8x)
./stream_minimal_adjustable_scale.sh

# Fixed 90% version (no parameters needed)
./stream_minimal_2x_no_cursor_90percent.sh
```

### **Stop Streaming**
```bash
# Press Ctrl+C in terminal, then cleanup:
pkill -f fuse      # Stop FUSE emulator
pkill -f Xvfb      # Stop virtual display
```

### **Monitor Stream**
```bash
# Check YouTube Studio
open https://studio.youtube.com

# Or in browser: https://studio.youtube.com
```

### **Diagnose Issues**
```bash
# Run diagnostic tool
./diagnose_fuse_window.sh

# Check processes
ps aux | grep fuse
ps aux | grep Xvfb
```

## 🎮 **Scaling Quick Reference**

| Command | Scale | Size | Use Case |
|---------|-------|------|----------|
| `./stream_minimal_adjustable_scale.sh 85` | 1.7x | 544x408 | Compact |
| `./stream_minimal_adjustable_scale.sh 90` | 1.8x | 576x432 | **OPTIMAL** |
| `./stream_minimal_adjustable_scale.sh 95` | 1.9x | 608x456 | Detailed |
| `./stream_minimal_adjustable_scale.sh 100` | 2.0x | 640x480 | Maximum |

## 🔧 **Troubleshooting Quick Fixes**

### **Stream Not Appearing**
```bash
# Check YouTube Studio dashboard
# Wait 10-15 seconds for stream to appear
# Verify internet connection
```

### **Wrong Size**
```bash
# Try different scaling
./stream_minimal_adjustable_scale.sh 85   # Smaller
./stream_minimal_adjustable_scale.sh 95   # Larger
```

### **Cursor Visible**
```bash
# Use golden reference scripts (cursor already hidden)
./stream_minimal_adjustable_scale.sh
```

### **Not Centered**
```bash
# Golden reference auto-centers
# If issues persist, run diagnostic:
./diagnose_fuse_window.sh
```

## 📊 **Expected Results**

### **Stream Quality**
- ✅ **Resolution**: 1280x720 HD
- ✅ **Frame Rate**: 30 FPS
- ✅ **Cursor**: Hidden
- ✅ **Centering**: Perfect
- ✅ **Scaling**: Pixel-perfect retro

### **Timing**
- **Startup**: 10-15 seconds
- **Stream Appears**: 10-15 seconds after startup
- **Latency**: 3-5 seconds (YouTube standard)

### **Visual Elements**
- **FUSE Window**: Centered, scaled, cursor-free
- **Timestamp**: Yellow overlay in top-right
- **Background**: Black padding around FUSE
- **Quality**: Broadcast-ready HD

## 🎯 **One-Liner Commands**

```bash
# Quick start (most common)
cd /home/ubuntu/workspace/SpeccyEmulator/local-test/local-fuse-test && ./stream_minimal_adjustable_scale.sh

# Quick start with custom scaling
cd /home/ubuntu/workspace/SpeccyEmulator/local-test/local-fuse-test && ./stream_minimal_adjustable_scale.sh 85

# Quick cleanup
pkill -f fuse; pkill -f Xvfb

# Quick diagnostic
cd /home/ubuntu/workspace/SpeccyEmulator/local-test/local-fuse-test && ./diagnose_fuse_window.sh
```

---

**🏆 GOLDEN REFERENCE**: `stream_minimal_adjustable_scale.sh` - Production-ready, cursor-free, adjustable FUSE streaming
