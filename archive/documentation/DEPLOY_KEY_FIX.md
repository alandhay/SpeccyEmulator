# Deploy Key Injection Fix - Simple Guide

## 🎯 **WHAT WAS FIXED**

Applied the **exact proven method** from local tests to your production server:

### ✅ **Critical Fixes Applied:**

1. **Added Timeout to xdotool** (Most Important Fix)
   ```python
   # BEFORE: No timeout (could hang)
   result = subprocess.run([...], capture_output=True, text=True)
   
   # AFTER: 5-second timeout (proven method)
   result = subprocess.run([...], capture_output=True, text=True, timeout=5)
   ```

2. **Added Timeout Exception Handling**
   ```python
   except subprocess.TimeoutExpired:
       logger.error(f"❌ Timeout sending key '{key}'")
       return False, "xdotool timeout"
   ```

3. **Added Window Validation Function**
   ```python
   def validate_fuse_window(self):
       # Checks if FUSE window exists before sending keys
   ```

4. **Enhanced Health Check**
   ```python
   # Now reports: "key_injection_ready": true/false
   ```

5. **Updated Dockerfile**
   - Ensures `xdotool` is installed (critical dependency)

## 🚀 **DEPLOYMENT STEPS**

### **Step 1: Build and Push Image**
```bash
cd /home/ubuntu/workspace/SpeccyEmulator
./deploy_key_fix.sh
```

This will:
- Build Docker image with proven key injection method
- Push to ECR as `spectrum-emulator:v6-proven-keys`

### **Step 2: Register New Task Definition**
```bash
aws ecs register-task-definition \
  --cli-input-json file://task-definition-v6-proven-keys.json
```

### **Step 3: Deploy to Development**
```bash
# Get the new revision number
NEW_REVISION=$(aws ecs describe-task-definition \
  --task-definition spectrum-emulator-streaming \
  --query 'taskDefinition.revision' --output text)

# Update the service
aws ecs update-service \
  --cluster spectrum-emulator-cluster-dev \
  --service spectrum-youtube-streaming \
  --task-definition spectrum-emulator-streaming:${NEW_REVISION}
```

### **Step 4: Test Key Injection**

1. **Open your livestream**: https://d112s3ps8xh739.cloudfront.net
2. **Try pressing keys** via the web interface
3. **Keys should appear immediately on the livestream** 🎉

### **Step 5: Verify Health Check**
```bash
curl https://d112s3ps8xh739.cloudfront.net/health
```

Should show:
```json
{
  "key_injection_ready": true,
  "fuse_window_valid": true,
  "fuse_window_id": "2097160"
}
```

## ✅ **SUCCESS CRITERIA**

- ✅ **Keys appear on livestream immediately** when pressed
- ✅ **No WebSocket error 1011** 
- ✅ **Health check shows** `"key_injection_ready": true`
- ✅ **Container starts successfully** within 2 minutes

## 🔧 **IF KEYS STILL DON'T WORK**

### **Check Health Endpoint**
```bash
curl https://d112s3ps8xh739.cloudfront.net/health
```

**If `"key_injection_ready": false`:**
- FUSE window not found
- Check container logs for FUSE startup issues

**If `"key_injection_ready": true` but keys don't appear:**
- WebSocket message handling issue
- Check browser console for WebSocket errors

### **Check Container Logs**
```bash
aws logs tail "/ecs/spectrum-emulator-streaming" --follow
```

Look for:
- ✅ `"✅ Successfully sent key 'H' to FUSE emulator"`
- ❌ `"❌ Failed to send key"` or `"❌ Timeout sending key"`

## 🎯 **WHY THIS WILL WORK**

1. **Same Method**: Exact same xdotool commands as proven local test
2. **Timeout Fix**: Prevents hanging that caused WebSocket error 1011
3. **Window Validation**: Ensures FUSE window exists before sending keys
4. **Proper Dependencies**: xdotool guaranteed to be installed

**The local test proved this method works - now it's applied to production with proper error handling.**

## 📋 **FILES CREATED**

- ✅ `server/emulator_server_fixed_v6.py` - Updated server with proven method
- ✅ `fixed-emulator-v6-keys.dockerfile` - Dockerfile with xdotool
- ✅ `task-definition-v6-proven-keys.json` - Task definition for deployment
- ✅ `deploy_key_fix.sh` - Build and push script
- ✅ `CORE_KEY_INJECTION_FIX.md` - Detailed technical documentation

**Ready to deploy the proven key injection fix!** 🚀
