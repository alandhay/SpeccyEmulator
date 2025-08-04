# 📁 ARCHIVE - Development History

This directory contains the development iterations that led to the golden reference script. These scripts are preserved for historical reference and learning purposes.

## 🏆 **GOLDEN REFERENCE (Current)**
**Location**: `../stream_minimal_adjustable_scale.sh`  
**Status**: ✅ Production Ready - Cursor-free, adjustable scaling

## 📚 **Development Timeline**

### **Phase 1: Initial Attempts**
- `stream_minimal.sh` - First working FUSE streaming
- `stream_fuse_robust.sh` - Stability improvements
- `stream_fuse_debug.sh` - Debug version with logging
- `stream_fuse_with_game.sh` - Game loading attempts
- `stream_fuse_to_youtube.sh` - YouTube integration

### **Phase 2: Scaling Experiments**
- `stream_minimal_2x.sh` - Basic 2x scaling
- `stream_minimal_2x_adaptive.sh` - **ORIGINAL PROBLEMATIC** - Scaled entire display
- `stream_minimal_3x_optimal.sh` - 3x scaling attempt
- `stream_minimal_3x_safe.sh` - Conservative 3x approach
- `stream_minimal_4x.sh` - 4x scaling experiment
- `stream_minimal_4x_adaptive.sh` - Adaptive 4x scaling

### **Phase 3: Centering Solutions**
- `stream_minimal_2x_offset_FIXED.sh` - Mathematical offset centering
- `stream_minimal_2x_centered_FIXED.sh` - Auto-detection centering
- `stream_minimal_2x_forced_center.sh` - Window manager centering
- `stream_minimal_2x_native_FIXED.sh` - Native resolution approach
- `stream_minimal_2x_adaptive_FIXED.sh` - Fixed adaptive scaling

### **Phase 4: Test Scripts**
- `test_fuse_display.sh` - Display testing
- `test_fuse_setup.sh` - Setup validation
- `simple_fuse_test.sh` - Basic functionality test

## 🔍 **Key Learning Points**

### **What Didn't Work**
1. **Scaling Entire Display**: `stream_minimal_2x_adaptive.sh` scaled 800x600 instead of FUSE window
2. **Complex Window Management**: Force-centering with window managers was unreliable
3. **Native Resolution Only**: Too restrictive for different use cases
4. **Fixed Scaling**: No flexibility for different streaming needs

### **What Led to Success**
1. **Center Capture**: Mathematical offset to capture FUSE area only
2. **Cursor Hiding**: `-draw_mouse 0` flag discovery
3. **Adjustable Scaling**: Command-line parameter flexibility
4. **Optimal Default**: 90% of 2x (1.8x) as perfect balance

## 📊 **Script Evolution**

```
stream_minimal.sh (Basic working)
├── stream_minimal_2x_adaptive.sh (PROBLEM: Wrong scaling area)
├── stream_minimal_2x_offset_FIXED.sh (FIX: Center capture)
├── stream_minimal_2x_no_cursor_90percent.sh (FIX: Hide cursor, 90% scale)
└── stream_minimal_adjustable_scale.sh (GOLDEN: Adjustable + cursor-free)
```

## 🎯 **Archive Purpose**

These scripts are preserved to:
- **Document Development Process**: Show iterative improvement
- **Preserve Learning**: Keep failed approaches for reference
- **Enable Debugging**: Compare working vs non-working versions
- **Historical Record**: Maintain complete development timeline

## ⚠️ **Usage Warning**

**DO NOT USE THESE ARCHIVED SCRIPTS FOR PRODUCTION**

- They contain known issues (cursor visible, wrong scaling, etc.)
- They are superseded by the golden reference
- They are kept for educational/historical purposes only

## 🚀 **For Current Usage**

Use the golden reference scripts in the parent directory:
```bash
cd ..
./stream_minimal_adjustable_scale.sh    # RECOMMENDED
./stream_minimal_2x_no_cursor_90percent.sh  # Alternative
```

---

**📁 This archive preserves the journey to the golden reference solution.**
