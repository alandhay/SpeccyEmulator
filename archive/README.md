# Archive Directory

This directory contains outdated files that were moved to clean up the main project structure.

## Archive Date
**Archived on:** August 4, 2025  
**Reason:** Project cleanup - moved outdated versions and experimental files

## Directory Structure

### `/dockerfiles/`
Contains outdated Dockerfile versions:
- Various versioned Dockerfiles (v3, v4, v5, v6)
- Experimental Dockerfiles (framebuffer, websockets, ultra-hd, etc.)
- Golden reference versions (superseded by OpenSE ROM version)

### `/task-definitions/`
Contains outdated ECS task definitions:
- All versioned task definitions
- Experimental configurations
- Service definitions
- Streaming configurations

### `/server-versions/`
Contains outdated Python server implementations:
- Various emulator server versions
- Experimental server implementations
- Fixed versions (superseded by OpenSE ROM version)

### `/build-scripts/`
Contains outdated build and deployment scripts:
- Old build scripts for various versions
- Trigger scripts for different streaming configurations
- YouTube streaming scripts
- Deployment scripts for experimental features

### `/test-scripts/`
Contains outdated test scripts:
- Golden reference test scripts
- Local test scripts
- Debug scripts

### `/python-scripts/`
Contains outdated Python utility scripts:
- Integration fix scripts
- Debug utilities
- Key injection fixes
- Test clients

### `/documentation/`
Contains outdated documentation:
- Version-specific deployment guides
- Fix documentation for resolved issues
- Status reports
- Implementation plans

## Current Active Files (Not Archived)

The following files remain active in the main project:

### **Core Files:**
- `README.md` - Main project documentation
- `fixed-emulator-opense-rom.dockerfile` - Current OpenSE ROM Dockerfile
- `fixed-emulator-golden-reference-v2-final.dockerfile` - Latest working version

### **Server:**
- `server/emulator_server_golden_reference_v2_final.py` - Current server with OpenSE ROM
- `server/requirements.txt` - Python dependencies
- `server/start.sh` - Server startup script

### **Docker Scripts:**
- `docker-build.sh` - Updated for OpenSE ROM
- `docker-start.sh` - Updated for OpenSE ROM
- `docker-stop.sh` - Updated container management
- `docker-status.sh` - Enhanced status reporting

### **OpenSE ROM Scripts:**
- `build-opense-rom.sh` - OpenSE ROM build script
- `test-opense-rom.sh` - OpenSE ROM test script
- `deploy-opense-rom.sh` - OpenSE ROM deployment script

### **Infrastructure:**
- `web/` - Frontend web interface
- `infrastructure/` - AWS infrastructure code
- `aws/` - AWS deployment configurations

## Recovery Instructions

If you need to recover any archived file:

1. **Locate the file** in the appropriate archive subdirectory
2. **Copy (don't move)** the file back to the main project directory
3. **Update any references** to match current project structure
4. **Test thoroughly** before using in production

## Notes

- All archived files were working at the time of archival
- The OpenSE ROM approach supersedes most of these implementations
- Some files may have historical value for understanding the project evolution
- Task definitions contain AWS-specific configurations that may be useful for reference

## Cleanup Benefits

Moving these files to archive provides:
- ✅ Cleaner main project directory
- ✅ Easier navigation for new developers
- ✅ Clear separation of current vs. historical code
- ✅ Preserved history for reference
- ✅ Reduced confusion about which files to use

## Current Project Focus

The project now focuses on:
- **OpenSE ROM implementation** - Legal, open-source ROM usage
- **Simplified Docker workflow** - Clear build/test/deploy process
- **Clean codebase** - Only current, working files in main directory
- **Better documentation** - Focused on current implementation
